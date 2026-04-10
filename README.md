# 🦋 Flutter Development Environment Setup

Automated scripts to install and configure everything needed to run Flutter apps — for **Ubuntu/Debian Linux**, **macOS**, and **Windows**.

## What Gets Installed

| Component | Description |
|-----------|-------------|
| **Flutter SDK** | Latest stable channel (includes Dart SDK) |
| **Android SDK** | Command-line tools, platform-tools, build-tools, platform API 34 |
| **Java JDK 17** | Required by Android SDK |
| **Git** | Required by Flutter for version control |
| **Platform tools** | OS-specific build dependencies (see below) |

### Platform-Specific Dependencies

| Ubuntu/Linux | macOS | Windows |
|:------------|:------|:--------|
| clang, cmake, ninja-build | Xcode CLI Tools | Visual Studio Build Tools |
| pkg-config, libgtk-3-dev | Homebrew | Git for Windows |
| libstdc++-12-dev | CocoaPods | Adoptium Temurin JDK 17 |
| libglu1-mesa | OpenJDK 17 | — |
| Google Chrome | — | — |

### Environment Variables Set

| Variable | Value |
|----------|-------|
| `FLUTTER_HOME` | `~/development/flutter` |
| `ANDROID_HOME` | `~/development/android-sdk` |
| `ANDROID_SDK_ROOT` | `~/development/android-sdk` |
| `JAVA_HOME` | System JDK 17 path |
| `PATH` | flutter/bin, dart-sdk/bin, cmdline-tools/bin, platform-tools |

---

## 🐧 Ubuntu / Debian Linux & 🍎 macOS

```bash
# 1. Make the script executable
chmod +x setup_flutter.sh

# 2. Run it
./setup_flutter.sh

# 3. Restart your terminal or source your shell config
source ~/.bashrc    # or ~/.zshrc on macOS
```

---

## 🪟 Windows

```powershell
# 1. Open PowerShell as Administrator

# 2. Allow script execution (for this session)
Set-ExecutionPolicy Bypass -Scope Process -Force

# 3. Run the script
.\setup_flutter.ps1

# 4. Restart PowerShell when done
```

---

## After Installation

```bash
# Verify everything is set up correctly
flutter doctor

# Create your first app
flutter create my_app
cd my_app
flutter run
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `flutter: command not found` | Restart your terminal or run `source ~/.bashrc` |
| Android licenses not accepted | Run `flutter doctor --android-licenses` |
| Linux desktop build fails | Run `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev` |
| macOS iOS build fails | Install full Xcode from App Store, then `sudo xcodebuild -license accept` |
| Windows desktop build fails | Install Visual Studio with "Desktop development with C++" workload |
