# dev-cleanup.sh

A macOS shell script for freeing up disk space by cleaning common **developer caches** (Flutter, Gradle, Android, Xcode, Node, CocoaPods, Python, Ruby, Homebrew, VS Code, etc.).

It’s designed for developers who often run out of space due to build artifacts and caches piling up.

---

## ✨ Features

- Stops Gradle daemons and clears Gradle/Android build caches
- Cleans Flutter & Dart caches
- Cleans Node / npm / yarn / pnpm caches
- Cleans CocoaPods and SwiftPM caches
- Cleans Python (`pip`), Ruby (`gem`), and Homebrew caches
- Cleans VS Code caches/logs
- **Optional**:
  - Xcode caches, DerivedData, DeviceSupport, old simulators (`--include-xcode`)
  - Docker unused containers/images/build cache (`--include-docker`)
  - Aggressive package cache removal (`--aggressive`) – e.g. Flutter pub-cache, npm tarballs

---

## 📦 Installation

Clone or download this repository, then make the script executable:

```bash
chmod +x dev-cleanup.sh
