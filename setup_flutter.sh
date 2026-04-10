#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Flutter Android Development Environment Setup Script (Linux)
#  Supports: Ubuntu/Debian Linux
#  
#  This script will:
#    1. Detect your operating system and architecture
#    2. Scan for already-installed tools & show status
#    3. Only download & install what's missing
#    4. Configure environment variables
#    5. Run flutter doctor to verify the setup
#
#  Usage:
#    chmod +x setup_flutter.sh
#    ./setup_flutter.sh
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Colors & Formatting ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─── Configuration ─────────────────────────────────────────────────
FLUTTER_CHANNEL="stable"
ANDROID_API_LEVEL="34"
ANDROID_BUILD_TOOLS_VERSION="34.0.0"
ANDROID_CMDLINE_TOOLS_VERSION="11076708" # latest as of 2025
INSTALL_DIR="$HOME/development"
FLUTTER_DIR="$INSTALL_DIR/flutter"
ANDROID_SDK_DIR="$INSTALL_DIR/android-sdk"

# ─── Status tracking (0 = not found, 1 = found) ───────────────────
HAS_GIT=0
HAS_CURL=0
HAS_WGET=0
HAS_UNZIP=0
HAS_XZ=0
HAS_ZIP=0
HAS_JAVA=0
HAS_ANDROID_STUDIO=0
HAS_FLUTTER=0
HAS_DART=0
HAS_ANDROID_CMDLINE=0
HAS_ANDROID_PLATFORM_TOOLS=0
HAS_ANDROID_BUILD_TOOLS=0
HAS_ANDROID_PLATFORM=0
HAS_ENV_CONFIGURED=0

MISSING_COUNT=0
INSTALLED_COUNT=0

# ─── Helper Functions ──────────────────────────────────────────────

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║                                                           ║"
    echo "  ║     🦋  Flutter Android Dev Environment Setup  🦋         ║"
    echo "  ║                                                           ║"
    echo "  ║   Automated installer for Linux (Ubuntu/Debian)           ║"
    echo "  ║                                                           ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    local step_num=$1
    local step_msg=$2
    echo ""
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}${BOLD}  STEP ${step_num}: ${step_msg}${NC}"
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

info()    { echo -e "${BLUE}  ℹ  ${NC}$1"; }
success() { echo -e "${GREEN}  ✅ ${NC}$1"; }
warn()    { echo -e "${YELLOW}  ⚠️  ${NC}$1"; }
fail()    { echo -e "${RED}  ❌ ${NC}$1"; exit 1; }
item()    { echo -e "${DIM}     •${NC} $1"; }

# Print a status row for the pre-check table
# Usage: status_row "Tool Name" "version_or_path" 1|0
status_row() {
    local name="$1"
    local detail="$2"
    local found=$3

    if [ "$found" -eq 1 ]; then
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        printf "  │  ${GREEN}✅ %-28s${NC} ${DIM}%s${NC}\n" "$name" "$detail"
    else
        MISSING_COUNT=$((MISSING_COUNT + 1))
        printf "  │  ${RED}❌ %-28s${NC} ${YELLOW}%s${NC}\n" "$name" "Not found — will install"
    fi
}

# ─── OS & Architecture Detection ──────────────────────────────────

detect_os() {
    print_step "1" "Detecting Operating System & Architecture"

    OS_TYPE=""
    OS_ARCH=""
    OS_NAME=""

    case "$(uname -s)" in
        Linux*)
            OS_TYPE="linux"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_NAME="${NAME} ${VERSION_ID:-}"
            else
                OS_NAME="Linux (unknown distro)"
            fi
            if ! command -v apt-get &>/dev/null; then
                fail "This script currently supports Ubuntu/Debian-based Linux distributions only (requires apt-get)."
            fi
            ;;
        *)
            fail "Unsupported operating system: $(uname -s). Use setup_flutter.ps1 for Windows."
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)   OS_ARCH="x64" ;;
        arm64|aarch64)   OS_ARCH="arm64" ;;
        *)               fail "Unsupported architecture: $(uname -m)" ;;
    esac

    echo ""
    echo -e "  ${BOLD}Detected Environment:${NC}"
    echo -e "  ┌──────────────────────────────────────────────┐"
    echo -e "  │  OS:           ${GREEN}${OS_NAME}${NC}"
    echo -e "  │  Type:         ${GREEN}${OS_TYPE}${NC}"
    echo -e "  │  Architecture: ${GREEN}${OS_ARCH}${NC}"
    echo -e "  │  User:         ${GREEN}$(whoami)${NC}"
    echo -e "  │  Home:         ${GREEN}${HOME}${NC}"
    echo -e "  └──────────────────────────────────────────────┘"
    echo ""
}

# ─── Pre-Installation Check ──────────────────────────────────────

# Helper: check if a command exists and capture its version
cmd_version() {
    local cmd="$1"
    local flag="${2:---version}"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" $flag 2>&1 | head -1) || ver="installed"
        echo "$ver"
        return 0
    fi
    return 1
}

check_existing() {
    print_step "2" "Scanning for Already-Installed Tools"

    echo ""
    echo -e "  ${BOLD}Checking what's already on your system...${NC}"
    echo ""

    MISSING_COUNT=0
    INSTALLED_COUNT=0

    # ── Core Utilities ──────────────────────────────────
    echo -e "  ${CYAN}┌─ Core Utilities ────────────────────────────────────────────────┐${NC}"

    local ver=""

    # Git
    if ver=$(cmd_version git); then HAS_GIT=1; fi
    status_row "Git" "$ver" $HAS_GIT

    # Curl
    if ver=$(cmd_version curl); then HAS_CURL=1; fi
    status_row "curl" "$ver" $HAS_CURL

    # Wget
    if ver=$(cmd_version wget); then HAS_WGET=1; fi
    status_row "wget" "$ver" $HAS_WGET

    # Unzip
    if ver=$(cmd_version unzip); then HAS_UNZIP=1; fi
    status_row "unzip" "$ver" $HAS_UNZIP

    # xz-utils (check for xz command)
    if ver=$(cmd_version xz); then HAS_XZ=1; fi
    status_row "xz-utils" "$ver" $HAS_XZ

    # zip
    if ver=$(cmd_version zip); then HAS_ZIP=1; fi
    status_row "zip" "$ver" $HAS_ZIP

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Java ────────────────────────────────────────────
    echo -e "  ${CYAN}┌─ Java Runtime ──────────────────────────────────────────────────┐${NC}"

    if ver=$(cmd_version java "-version"); then HAS_JAVA=1; fi
    status_row "Java JDK 17" "$ver" $HAS_JAVA

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Android Studio ─────────────────────────────────
    echo -e "  ${CYAN}┌─ Android Studio ──────────────────────────────────────────────────┐${NC}"

    ver=""
    # Check common Android Studio install locations on Linux
    local as_paths=(
        "/opt/android-studio/bin/studio.sh"
        "/usr/local/android-studio/bin/studio.sh"
        "$HOME/android-studio/bin/studio.sh"
        "/snap/android-studio/current/android-studio/bin/studio.sh"
    )
    for as_path in "${as_paths[@]}"; do
        if [ -f "$as_path" ]; then
            HAS_ANDROID_STUDIO=1
            ver="installed @ $(dirname "$(dirname "$as_path")")"
            break
        fi
    done
    # Also check if it's available via command/snap
    if [ $HAS_ANDROID_STUDIO -eq 0 ]; then
        if command -v android-studio &>/dev/null; then
            HAS_ANDROID_STUDIO=1
            ver="installed (snap)"
        elif snap list android-studio &>/dev/null 2>&1; then
            HAS_ANDROID_STUDIO=1
            ver="installed (snap)"
        fi
    fi
    status_row "Android Studio" "$ver" $HAS_ANDROID_STUDIO

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Flutter & Dart ──────────────────────────────────
    echo -e "  ${CYAN}┌─ Flutter SDK ───────────────────────────────────────────────────┐${NC}"

    if [ -f "$FLUTTER_DIR/bin/flutter" ]; then
        HAS_FLUTTER=1
        ver=$("$FLUTTER_DIR/bin/flutter" --version --machine 2>/dev/null | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4 || echo "installed")
        ver="v${ver} @ ${FLUTTER_DIR}"
    elif command -v flutter &>/dev/null; then
        HAS_FLUTTER=1
        ver=$(flutter --version 2>/dev/null | head -1)
    else
        ver=""
    fi
    status_row "Flutter SDK" "$ver" $HAS_FLUTTER

    if [ -f "$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart" ]; then
        HAS_DART=1
        ver=$("$FLUTTER_DIR/bin/cache/dart-sdk/bin/dart" --version 2>&1 | head -1)
    elif command -v dart &>/dev/null; then
        HAS_DART=1
        ver=$(dart --version 2>&1 | head -1)
    else
        ver=""
    fi
    status_row "Dart SDK (bundled)" "$ver" $HAS_DART

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Android SDK ─────────────────────────────────────
    echo -e "  ${CYAN}┌─ Android SDK ───────────────────────────────────────────────────┐${NC}"

    if [ -d "$ANDROID_SDK_DIR/cmdline-tools/latest/bin" ]; then
        HAS_ANDROID_CMDLINE=1; ver="$ANDROID_SDK_DIR/cmdline-tools/latest"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/cmdline-tools/latest/bin" ]; then
        HAS_ANDROID_CMDLINE=1; ver="${ANDROID_HOME}/cmdline-tools/latest"
    else
        ver=""
    fi
    status_row "Android Command-Line Tools" "$ver" $HAS_ANDROID_CMDLINE

    if [ -d "$ANDROID_SDK_DIR/platform-tools" ]; then
        HAS_ANDROID_PLATFORM_TOOLS=1; ver="$ANDROID_SDK_DIR/platform-tools"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/platform-tools" ]; then
        HAS_ANDROID_PLATFORM_TOOLS=1; ver="${ANDROID_HOME}/platform-tools"
    else
        ver=""
    fi
    status_row "Android Platform Tools" "$ver" $HAS_ANDROID_PLATFORM_TOOLS

    if [ -d "$ANDROID_SDK_DIR/build-tools/${ANDROID_BUILD_TOOLS_VERSION}" ]; then
        HAS_ANDROID_BUILD_TOOLS=1; ver="v${ANDROID_BUILD_TOOLS_VERSION}"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}" ]; then
        HAS_ANDROID_BUILD_TOOLS=1; ver="v${ANDROID_BUILD_TOOLS_VERSION}"
    else
        ver=""
    fi
    status_row "Android Build Tools" "$ver" $HAS_ANDROID_BUILD_TOOLS

    if [ -d "$ANDROID_SDK_DIR/platforms/android-${ANDROID_API_LEVEL}" ]; then
        HAS_ANDROID_PLATFORM=1; ver="API ${ANDROID_API_LEVEL}"
    elif [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/platforms/android-${ANDROID_API_LEVEL}" ]; then
        HAS_ANDROID_PLATFORM=1; ver="API ${ANDROID_API_LEVEL}"
    else
        ver=""
    fi
    status_row "Android Platform" "$ver" $HAS_ANDROID_PLATFORM

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Environment Variables ───────────────────────────
    echo -e "  ${CYAN}┌─ Environment Variables ─────────────────────────────────────────┐${NC}"

    local shell_rc=""
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi

    if grep -q "FLUTTER_HOME" "$shell_rc" 2>/dev/null; then
        HAS_ENV_CONFIGURED=1; ver="Configured in $shell_rc"
    else
        ver=""
    fi
    status_row "Shell env (FLUTTER_HOME, etc.)" "$ver" $HAS_ENV_CONFIGURED

    echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────────┘${NC}"

    # ── Summary ─────────────────────────────────────────
    echo ""
    echo -e "  ┌──────────────────────────────────────────────┐"
    echo -e "  │  ${GREEN}✅ Already installed:  ${BOLD}${INSTALLED_COUNT}${NC}"
    echo -e "  │  ${RED}❌ Missing / to install: ${BOLD}${MISSING_COUNT}${NC}"
    echo -e "  └──────────────────────────────────────────────┘"
    echo ""

    if [ "$MISSING_COUNT" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}🎉 Everything is already installed!${NC}"
        echo ""
        read -rp "  $(echo -e ${YELLOW})Run flutter doctor to verify? [Y/n]:$(echo -e ${NC}) " confirm
        confirm=${confirm:-Y}
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            verify_installation
        fi
        echo ""
        echo -e "  ${DIM}Nothing to do. Exiting.${NC}"
        exit 0
    fi

    read -rp "  $(echo -e ${YELLOW})Install the ${MISSING_COUNT} missing component(s)? [Y/n]:$(echo -e ${NC}) " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Installation cancelled by user."
        exit 0
    fi
}

# ─── Install System Dependencies ─────────────────────────────────

install_dependencies() {
    print_step "3" "Installing Missing System Dependencies"

    # Collect missing apt packages
    local pkgs_to_install=()

    if [ $HAS_CURL -eq 0 ];      then pkgs_to_install+=(curl); fi
    if [ $HAS_GIT -eq 0 ];       then pkgs_to_install+=(git); fi
    if [ $HAS_WGET -eq 0 ];      then pkgs_to_install+=(wget); fi
    if [ $HAS_UNZIP -eq 0 ];     then pkgs_to_install+=(unzip); fi
    if [ $HAS_XZ -eq 0 ];        then pkgs_to_install+=(xz-utils); fi
    if [ $HAS_ZIP -eq 0 ];       then pkgs_to_install+=(zip); fi
    if [ $HAS_JAVA -eq 0 ];      then pkgs_to_install+=(openjdk-17-jdk); fi

    # Always include these basics if any package needs installing
    if [ ${#pkgs_to_install[@]} -gt 0 ]; then
        pkgs_to_install+=(ca-certificates gnupg lsb-release)
    fi

    if [ ${#pkgs_to_install[@]} -eq 0 ]; then
        success "All system packages are already installed. Skipping."
    else
        info "Packages to install: ${pkgs_to_install[*]}"
        echo ""

        info "Updating package lists..."
        sudo apt-get update -y

        info "Installing ${#pkgs_to_install[@]} package(s)..."
        sudo apt-get install -y "${pkgs_to_install[@]}"
        success "System packages installed."
    fi

    echo ""
    success "System dependencies done!"
}

# ─── Install Android Studio ──────────────────────────────────────

install_android_studio() {
    print_step "3b" "Android Studio"

    if [ $HAS_ANDROID_STUDIO -eq 1 ]; then
        success "Android Studio is already installed. Skipping."
        return
    fi

    info "Installing Android Studio..."

    # Try snap first (easiest on Ubuntu)
    if command -v snap &>/dev/null; then
        info "Installing via snap (recommended for Ubuntu)..."
        sudo snap install android-studio --classic && \
        success "Android Studio installed via snap!" && return || \
        warn "Snap installation failed, trying manual download..."
    fi

    # Fallback: download and extract tarball
    local as_version="2024.2.2.13"
    local as_url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/${as_version}/android-studio-${as_version}-linux.tar.gz"
    local tmp_tar="/tmp/android-studio.tar.gz"

    info "Downloading Android Studio..."
    item "URL: ${as_url}"
    wget -q --show-progress -O "$tmp_tar" "$as_url"
    success "Download complete."

    info "Extracting to /opt/android-studio..."
    sudo tar -xzf "$tmp_tar" -C /opt/
    rm -f "$tmp_tar"

    # Create desktop entry for easy launching
    if [ -d "$HOME/.local/share/applications" ]; then
        cat > "$HOME/.local/share/applications/android-studio.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Icon=/opt/android-studio/bin/studio.svg
Exec=/opt/android-studio/bin/studio.sh
Categories=Development;IDE;
Terminal=false
StartupNotify=true
EOF
        success "Desktop entry created."
    fi

    if [ -f "/opt/android-studio/bin/studio.sh" ]; then
        success "Android Studio installed to /opt/android-studio"
    else
        warn "Android Studio installation may have failed."
        warn "You can download manually from: https://developer.android.com/studio"
    fi
}

# ─── Install Flutter SDK ─────────────────────────────────────────

install_flutter() {
    print_step "4" "Flutter SDK"

    if [ $HAS_FLUTTER -eq 1 ]; then
        success "Flutter SDK already installed at ${FLUTTER_DIR}. Skipping download."
        info "Tip: run 'flutter upgrade' to update to the latest version."
        return
    fi

    mkdir -p "$INSTALL_DIR"

    info "Cloning Flutter SDK (${FLUTTER_CHANNEL} channel)..."
    info "This may take a few minutes depending on your internet speed..."
    echo ""

    git clone https://github.com/flutter/flutter.git -b "${FLUTTER_CHANNEL}" "$FLUTTER_DIR"

    success "Flutter SDK downloaded to: ${FLUTTER_DIR}"

    info "Running initial Flutter setup (downloading Dart SDK, tools)..."
    "$FLUTTER_DIR/bin/flutter" precache
    success "Flutter pre-cache complete!"

    echo ""
    echo -e "  ${BOLD}Flutter Info:${NC}"
    "$FLUTTER_DIR/bin/flutter" --version
    echo ""
}

# ─── Install Android SDK ─────────────────────────────────────────

install_android_sdk() {
    print_step "5" "Android SDK (Command-Line Tools)"

    # If everything Android-related is already installed, skip entirely
    if [ $HAS_ANDROID_CMDLINE -eq 1 ] && [ $HAS_ANDROID_PLATFORM_TOOLS -eq 1 ] && \
       [ $HAS_ANDROID_BUILD_TOOLS -eq 1 ] && [ $HAS_ANDROID_PLATFORM -eq 1 ]; then
        success "Android SDK is fully installed. Skipping."
        return
    fi

    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"

    # Install cmdline-tools if missing
    if [ $HAS_ANDROID_CMDLINE -eq 0 ]; then
        local cmdline_zip="commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
        local download_url="https://dl.google.com/android/repository/${cmdline_zip}"
        local tmp_zip="/tmp/${cmdline_zip}"

        info "Downloading Android Command-Line Tools..."
        item "URL: ${download_url}"
        wget -q --show-progress -O "$tmp_zip" "$download_url"
        success "Download complete."

        info "Extracting..."
        unzip -qo "$tmp_zip" -d "/tmp/android-cmdline-tools-extract"
        mv "/tmp/android-cmdline-tools-extract/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
        rm -rf "/tmp/android-cmdline-tools-extract" "$tmp_zip"
        success "Android Command-Line Tools installed."
    else
        success "Android Command-Line Tools already installed. Skipping."
    fi

    # Set ANDROID_HOME temporarily for sdkmanager
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$PATH"

    # Only install missing SDK components
    local sdk_packages=()
    if [ $HAS_ANDROID_PLATFORM_TOOLS -eq 0 ]; then sdk_packages+=("platform-tools"); fi
    if [ $HAS_ANDROID_PLATFORM -eq 0 ];       then sdk_packages+=("platforms;android-${ANDROID_API_LEVEL}"); fi
    if [ $HAS_ANDROID_BUILD_TOOLS -eq 0 ];    then sdk_packages+=("build-tools;${ANDROID_BUILD_TOOLS_VERSION}"); fi

    if [ ${#sdk_packages[@]} -gt 0 ]; then
        info "Installing missing Android SDK components:"
        for pkg in "${sdk_packages[@]}"; do
            item "$pkg"
        done
        echo ""

        yes | sdkmanager --sdk_root="$ANDROID_SDK_DIR" "${sdk_packages[@]}" 2>/dev/null || true
        success "Android SDK components installed!"
    else
        success "All Android SDK components already installed. Skipping."
    fi

    info "Accepting Android SDK licenses..."
    yes | sdkmanager --sdk_root="$ANDROID_SDK_DIR" --licenses 2>/dev/null || true
    success "Android licenses accepted."
}

# ─── Configure Environment Variables ─────────────────────────────

configure_env() {
    print_step "6" "Configuring Environment Variables"

    # Determine shell config file
    local shell_rc=""
    local shell_name=""

    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
    elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
    else
        shell_rc="$HOME/.profile"
        shell_name="profile"
    fi

    local profile_rc="$HOME/.profile"

    if [ $HAS_ENV_CONFIGURED -eq 1 ]; then
        success "Environment variables already configured in ${shell_rc}. Skipping."
        info "If paths have changed, delete the Flutter block in ${shell_rc} and re-run."
    else
        info "Shell detected: ${shell_name}"
        info "Config file: ${shell_rc}"

        local env_block="
# ═══════════════════════════════════════════════════════════════════
# Flutter Android Development Environment (auto-configured by setup_flutter.sh)
# ═══════════════════════════════════════════════════════════════════

# Flutter SDK
export FLUTTER_HOME=\"${FLUTTER_DIR}\"
export PATH=\"\$FLUTTER_HOME/bin:\$PATH\"

# Dart SDK (bundled with Flutter)
export PATH=\"\$FLUTTER_HOME/bin/cache/dart-sdk/bin:\$PATH\"

# Android SDK
export ANDROID_HOME=\"${ANDROID_SDK_DIR}\"
export ANDROID_SDK_ROOT=\"${ANDROID_SDK_DIR}\"
export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$PATH\"
export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\"
export PATH=\"\$ANDROID_HOME/build-tools/${ANDROID_BUILD_TOOLS_VERSION}:\$PATH\"

# Java
export JAVA_HOME=\"/usr/lib/jvm/java-17-openjdk-amd64\"
# ═══════════════════════════════════════════════════════════════════"

        echo "$env_block" >> "$shell_rc"
        success "Environment variables added to ${shell_rc}"

        if [ "$shell_rc" != "$profile_rc" ]; then
            if ! grep -q "FLUTTER_HOME" "$profile_rc" 2>/dev/null; then
                echo "$env_block" >> "$profile_rc"
                success "Environment variables also added to ${profile_rc}"
            fi
        fi
    fi

    # Always export for current session
    export FLUTTER_HOME="$FLUTTER_DIR"
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
    export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$ANDROID_SDK_DIR/build-tools/${ANDROID_BUILD_TOOLS_VERSION}:$PATH"

    echo ""
    echo -e "  ${BOLD}Active Environment:${NC}"
    echo -e "  ┌──────────────────────────────────────────────────────────┐"
    echo -e "  │  FLUTTER_HOME    = ${GREEN}${FLUTTER_DIR}${NC}"
    echo -e "  │  ANDROID_HOME    = ${GREEN}${ANDROID_SDK_DIR}${NC}"
    echo -e "  │  ANDROID_SDK_ROOT= ${GREEN}${ANDROID_SDK_DIR}${NC}"
    echo -e "  │  JAVA_HOME       = ${GREEN}/usr/lib/jvm/java-17-openjdk-amd64${NC}"
    echo -e "  │  PATH additions:"
    echo -e "  │    ${DIM}+ ${FLUTTER_DIR}/bin${NC}"
    echo -e "  │    ${DIM}+ ${ANDROID_SDK_DIR}/cmdline-tools/latest/bin${NC}"
    echo -e "  │    ${DIM}+ ${ANDROID_SDK_DIR}/platform-tools${NC}"
    echo -e "  └──────────────────────────────────────────────────────────┘"
    echo ""
}

# ─── Configure Flutter ────────────────────────────────────────────

configure_flutter() {
    print_step "7" "Configuring Flutter"

    info "Setting Android SDK path in Flutter..."
    "$FLUTTER_DIR/bin/flutter" config --android-sdk "$ANDROID_SDK_DIR" 2>/dev/null || true
    success "Android SDK configured in Flutter."

    info "Accepting Android licenses via Flutter..."
    yes | "$FLUTTER_DIR/bin/flutter" doctor --android-licenses 2>/dev/null || true
    success "Licenses accepted."
}

# ─── Verify Installation ─────────────────────────────────────────

verify_installation() {
    print_step "8" "Verifying Installation (flutter doctor)"

    echo ""
    "$FLUTTER_DIR/bin/flutter" doctor -v
    echo ""
}

# ─── Final Summary ───────────────────────────────────────────────

print_summary() {
    local shell_rc=""
    if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║                                                           ║"
    echo "  ║        🎉  Setup Complete!  🎉                            ║"
    echo "  ║                                                           ║"
    echo "  ╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Restart your terminal or run:"
    echo -e "     ${DIM}source ${shell_rc}${NC}"
    echo ""
    echo -e "  ${CYAN}2.${NC} Open Android Studio and configure your emulator"
    echo ""
    echo -e "  ${CYAN}3.${NC} Create a new Flutter project:"
    echo -e "     ${DIM}flutter create my_app${NC}"
    echo ""
    echo -e "  ${CYAN}4.${NC} Run your app on Android:"
    echo -e "     ${DIM}cd my_app && flutter run${NC}"
    echo ""
    echo -e "  ${CYAN}5.${NC} Check setup anytime:"
    echo -e "     ${DIM}flutter doctor${NC}"
    echo ""
    echo -e "  ${BOLD}Installed Locations:${NC}"
    echo -e "     Flutter SDK:      ${GREEN}${FLUTTER_DIR}${NC}"
    echo -e "     Android SDK:      ${GREEN}${ANDROID_SDK_DIR}${NC}"
    echo -e "     Android Studio:   ${GREEN}Check /opt/android-studio or snap${NC}"
    echo ""
    echo -e "  ${DIM}Script completed at: $(date)${NC}"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────

main() {
    print_banner
    detect_os
    check_existing           # ← scans everything, shows status, asks to proceed
    install_dependencies     # ← only installs missing packages
    install_android_studio   # ← skips if already installed
    install_flutter          # ← skips if already present
    install_android_sdk      # ← skips installed components
    configure_env            # ← skips if already configured
    configure_flutter
    verify_installation
    print_summary
}

main "$@"
