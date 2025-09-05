#!/usr/bin/env bash
set -euo pipefail

### dev-cleanup.sh — macOS developer cache cleaner and more..?
### DOES NOT remove Android emulators/AVDs or Xcode simulators.

DRY_RUN=false
INCLUDE_XCODE=false
INCLUDE_DOCKER=false
AGGRESSIVE=false

function usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run         Show what would be removed, but don't remove it
  --include-xcode   Also clean Xcode caches (DerivedData, DeviceSupport, etc.)
  --include-docker  Also prune Docker (stopped containers, dangling images, build cache)
  --aggressive      Remove larger language caches (npm/yarn/pnpm/pip/gems/pub hosted, etc.)
  -h, --help        Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --include-xcode) INCLUDE_XCODE=true ;;
    --include-docker) INCLUDE_DOCKER=true ;;
    --aggressive) AGGRESSIVE=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

function say()       { echo -e "\n\033[1;36m▶ $*\033[0m"; }
function done_msg()  { echo -e "\033[1;32m✓ $*\033[0m"; }
function warn()      { echo -e "\033[1;33m! $*\033[0m"; }
function info()      { echo "   $*"; }

function bytes_to_h() {
  # humanize a byte size input
  local bytes=$1
  awk -v sum="$bytes" 'function human(x){ s="B KB MB GB TB PB"; while (x>=1024 && s) {x/=1024; s=substr(s, index(s," ")+1)}; return sprintf("%.1f %s", x, substr(s,1,index(s," ")-1)); } BEGIN{ print human(sum) }'
}

TOTAL_FREED=0

function size_of() {
  # prints bytes size of path(s), ignoring errors
  local total=0
  for p in "$@"; do
    if [ -e "$p" ]; then
      local b
      b=$(du -sk "$p" 2>/dev/null | awk '{print $1}')
      b=$((b * 1024))
      total=$((total + b))
    fi
  done
  echo "$total"
}

function remove_path() {
  local path="$1"
  local label="${2:-$path}"
  if [ ! -e "$path" ]; then
    info "$label — not found, skipping."
    return
  fi
  local sz
  sz=$(size_of "$path")
  info "$label — $(bytes_to_h "$sz")"
  if [ "$DRY_RUN" = true ]; then
    info "(dry-run) rm -rf \"$path\""
  else
    rm -rf "$path"
    TOTAL_FREED=$((TOTAL_FREED + sz))
  fi
}

function run_cmd() {
  local desc="$1"; shift
  say "$desc"
  info "Command: $*"
  if [ "$DRY_RUN" = true ]; then
    info "(dry-run) not executing"
  else
    "$@"
  fi
}

say "Starting dev cleanup (dry-run: $DRY_RUN, include-xcode: $INCLUDE_XCODE, include-docker: $INCLUDE_DOCKER, aggressive: $AGGRESSIVE)"
say "Disk before:"
df -h /

########################################
# Gradle & Android build caches
########################################
say "Stopping Gradle daemon (if any)"
if [ -f "./android/gradlew" ]; then
  run_cmd "Gradle stop via project wrapper" bash -lc 'cd android && chmod +x gradlew && ./gradlew --stop || true'
else
  info "No local gradle wrapper found at ./android/gradlew — trying global"
  run_cmd "Global gradle stop" bash -lc 'gradle --stop 2>/dev/null || true'
fi

say "Cleaning Flutter project builds"
run_cmd "flutter clean" bash -lc 'command -v flutter >/dev/null && flutter clean || true'
remove_path "build" "Project build/"
remove_path "android/build" "Android module build/"
remove_path "android/.gradle" "Android .gradle (project)"

say "Cleaning user Gradle caches"
remove_path "$HOME/.gradle/caches" "~/.gradle/caches"
remove_path "$HOME/.gradle/wrapper/dists" "~/.gradle/wrapper/dists"
remove_path "$HOME/.android/build-cache" "~/.android/build-cache"

say "Cleaning Android Studio & IntelliJ caches (safe)"
remove_path "$HOME/Library/Caches/Google/AndroidStudio*" "~/Library/Caches/Google/AndroidStudio*"
remove_path "$HOME/Library/Logs/Google/AndroidStudio*" "~/Library/Logs/Google/AndroidStudio*"
remove_path "$HOME/Library/Application Support/Google/AndroidStudio*/log" "~/Library/Application Support/Google/AndroidStudio*/log"
remove_path "$HOME/Library/Caches/JetBrains/*" "~/Library/Caches/JetBrains/*"

warn "Not removing AVDs or system images (your emulators stay intact)."

########################################
# Flutter & Dart caches
########################################
say "Cleaning Flutter & Dart caches"
if [ "$AGGRESSIVE" = true ]; then
  remove_path "$HOME/.pub-cache/hosted" "~/.pub-cache/hosted (Dart/Flutter packages)"
  remove_path "$HOME/.pub-cache/git" "~/.pub-cache/git"
else
  info "Aggressive flag not set — skipping ~/.pub-cache to avoid large re-downloads."
fi
remove_path "$HOME/Library/Caches/DartAnalysisServer" "Dart Analysis Server cache"

########################################
# Node / JS package managers
########################################
say "Cleaning Node/JS package manager caches"
if command -v npm >/dev/null; then
  run_cmd "npm cache clean --force" npm cache clean --force
  remove_path "$HOME/.npm/_cacache" "~/.npm/_cacache"
fi
if command -v yarn >/dev/null; then
  run_cmd "yarn cache clean" yarn cache clean
fi
if command -v pnpm >/dev/null; then
  run_cmd "pnpm store prune" pnpm store prune
  remove_path "$HOME/Library/pnpm/store" "~/Library/pnpm/store"
fi

########################################
# CocoaPods / iOS dev (non-Xcode bits)
########################################
say "Cleaning CocoaPods caches"
if command -v pod >/dev/null; then
  run_cmd "pod cache clean --all" pod cache clean --all
  remove_path "$HOME/Library/Caches/CocoaPods" "~/Library/Caches/CocoaPods"
  remove_path "$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex" "Xcode ModuleCache.noindex (safe)"
else
  info "CocoaPods not installed — skipping."
fi

########################################
# SwiftPM & general Apple dev caches
########################################
say "Cleaning Swift Package Manager caches"
remove_path "$HOME/Library/Caches/org.swift.swiftpm" "~/Library/Caches/org.swift.swiftpm"
remove_path "$HOME/.swiftpm/cache" "~/.swiftpm/cache"

########################################
# Python & Ruby caches
########################################
say "Cleaning Python & Ruby caches (safe)"
if command -v pip >/dev/null; then
  run_cmd "pip cache purge" pip cache purge
fi
remove_path "$HOME/Library/Caches/pip" "~/Library/Caches/pip"
remove_path "$HOME/Library/Caches/pypoetry" "~/Library/Caches/pypoetry"

remove_path "$HOME/Library/Caches/rubygems" "~/Library/Caches/rubygems"
if command -v gem >/dev/null; then
  run_cmd "gem cleanup (leaves latest versions)" gem cleanup
fi

########################################
# Homebrew caches
########################################
say "Cleaning Homebrew caches"
if command -v brew >/dev/null; then
  run_cmd "brew cleanup -s" brew cleanup -s
  # Remove downloaded tarballs
  CACHE_DIR=$(brew --cache 2>/dev/null || echo "$HOME/Library/Caches/Homebrew")
  remove_path "$CACHE_DIR" "Homebrew cache directory"
else
  info "Homebrew not installed — skipping."
fi

########################################
# VS Code & general editor caches (safe)
########################################
say "Cleaning VS Code cache/logs (safe)"
remove_path "$HOME/Library/Application Support/Code/Cache" "VS Code Cache"
remove_path "$HOME/Library/Application Support/Code/CachedData" "VS Code CachedData"
remove_path "$HOME/Library/Application Support/Code/Service Worker/CacheStorage" "VS Code SW CacheStorage"
remove_path "$HOME/Library/Logs/Code" "VS Code Logs"

########################################
# Optional: Xcode cleanup
########################################
if [ "$INCLUDE_XCODE" = true ]; then
  say "Xcode cleanup enabled"
  remove_path "$HOME/Library/Developer/Xcode/DerivedData" "Xcode DerivedData"
  remove_path "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "Xcode iOS DeviceSupport"
  remove_path "$HOME/Library/Developer/Xcode/watchOS DeviceSupport" "Xcode watchOS DeviceSupport"
  remove_path "$HOME/Library/Developer/Xcode/tvOS DeviceSupport" "Xcode tvOS DeviceSupport"
  run_cmd "Delete unavailable simulators" xcrun simctl delete unavailable
  remove_path "$HOME/Library/Caches/com.apple.dt.Xcode" "Xcode caches"
  remove_path "$HOME/Library/Caches/org.carthage.CarthageKit" "Carthage cache"
  remove_path "$HOME/Library/Developer/CoreSimulator/Caches" "CoreSimulator caches"
  remove_path "$HOME/Library/Logs/CoreSimulator" "CoreSimulator logs"
else
  info "Xcode cleanup not requested (use --include-xcode)."
fi

########################################
# Optional: Docker cleanup
########################################
if [ "$INCLUDE_DOCKER" = true ]; then
  if command -v docker >/dev/null; then
    say "Docker cleanup enabled"
    run_cmd "docker system prune -f" docker system prune -f
    run_cmd "docker builder prune -af" docker builder prune -af
    # Not removing images/volumes in use; add with caution if needed.
  else
    info "Docker not installed — skipping."
  fi
else
  info "Docker cleanup not requested (use --include-docker)."
fi

say "Disk after:"
df -h /

if [ "$DRY_RUN" = true ]; then
  warn "Dry run completed. No files were removed."
else
  done_msg "Cleanup completed. Estimated freed: $(bytes_to_h "$TOTAL_FREED") (plus tool-level cleanups)."
fi