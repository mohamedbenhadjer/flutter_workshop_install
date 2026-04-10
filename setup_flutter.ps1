# ═══════════════════════════════════════════════════════════════════
#  Flutter Development Environment Setup Script (Windows)
#  Requires: Windows 10 or later, PowerShell 5.0+
#
#  This script will:
#    1. Detect your system architecture
#    2. Scan for already-installed tools & show status
#    3. Only download & install what's missing
#    4. Configure environment variables (User-level)
#    5. Run flutter doctor to verify the setup
#
#  Usage (Run as Administrator):
#    Set-ExecutionPolicy Bypass -Scope Process -Force
#    .\setup_flutter.ps1
# ═══════════════════════════════════════════════════════════════════

#Requires -Version 5.0

# ─── Configuration ─────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

$FLUTTER_CHANNEL = "stable"
$ANDROID_API_LEVEL = "34"
$ANDROID_BUILD_TOOLS_VERSION = "34.0.0"
$ANDROID_CMDLINE_TOOLS_VERSION = "11076708"
$INSTALL_DIR = "$env:USERPROFILE\development"
$FLUTTER_DIR = "$INSTALL_DIR\flutter"
$ANDROID_SDK_DIR = "$INSTALL_DIR\android-sdk"

# ─── Status tracking ──────────────────────────────────────────────
$script:HAS_GIT = $false
$script:HAS_JAVA = $false
$script:HAS_VS_CPP = $false
$script:HAS_FLUTTER = $false
$script:HAS_DART = $false
$script:HAS_ANDROID_CMDLINE = $false
$script:HAS_ANDROID_PLATFORM_TOOLS = $false
$script:HAS_ANDROID_BUILD_TOOLS = $false
$script:HAS_ANDROID_PLATFORM = $false
$script:HAS_ENV_CONFIGURED = $false

$script:MISSING_COUNT = 0
$script:INSTALLED_COUNT = 0

# ─── Helper Functions ──────────────────────────────────────────────

function Print-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                           ║" -ForegroundColor Cyan
    Write-Host "  ║        Flutter Dev Environment Setup (Windows)            ║" -ForegroundColor Cyan
    Write-Host "  ║                                                           ║" -ForegroundColor Cyan
    Write-Host "  ║   Automated installer for Windows 10/11                   ║" -ForegroundColor Cyan
    Write-Host "  ║                                                           ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Step {
    param([string]$StepNum, [string]$StepMsg)
    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
    Write-Host "  STEP ${StepNum}: ${StepMsg}" -ForegroundColor Magenta
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
}

function Info    { param([string]$Msg) Write-Host "  [i] $Msg" -ForegroundColor Blue }
function Success { param([string]$Msg) Write-Host "  [+] $Msg" -ForegroundColor Green }
function Warn    { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Fail    { param([string]$Msg) Write-Host "  [x] $Msg" -ForegroundColor Red; exit 1 }
function Item    { param([string]$Msg) Write-Host "      - $Msg" -ForegroundColor DarkGray }

function Status-Row {
    param([string]$Name, [string]$Detail, [bool]$Found)

    $paddedName = $Name.PadRight(30)
    if ($Found) {
        $script:INSTALLED_COUNT++
        Write-Host "  |  " -NoNewline
        Write-Host "[OK] $paddedName" -ForegroundColor Green -NoNewline
        Write-Host " $Detail" -ForegroundColor DarkGray
    } else {
        $script:MISSING_COUNT++
        Write-Host "  |  " -NoNewline
        Write-Host "[--] $paddedName" -ForegroundColor Red -NoNewline
        Write-Host " Not found - will install" -ForegroundColor Yellow
    }
}

# ─── Check Prerequisites ──────────────────────────────────────────

function Check-Prerequisites {
    Print-Step "0" "Checking Prerequisites"

    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Fail "Windows 10 or later is required. Current: $osVersion"
    }
    Success "Windows version OK: $([Environment]::OSVersion.VersionString)"

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Warn "Running without Administrator privileges. Some operations may fail."
        Warn "Consider re-running as Administrator for best results."
    } else {
        Success "Running with Administrator privileges."
    }
}

# ─── Detect System ────────────────────────────────────────────────

function Detect-System {
    Print-Step "1" "Detecting System Information"

    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $osInfo = Get-CimInstance Win32_OperatingSystem

    Write-Host ""
    Write-Host "  Detected Environment:"
    Write-Host "  +----------------------------------------------+"
    Write-Host "  |  OS:           " -NoNewline; Write-Host "$($osInfo.Caption)" -ForegroundColor Green
    Write-Host "  |  Architecture: " -NoNewline; Write-Host "$arch" -ForegroundColor Green
    Write-Host "  |  User:         " -NoNewline; Write-Host "$env:USERNAME" -ForegroundColor Green
    Write-Host "  |  Home:         " -NoNewline; Write-Host "$env:USERPROFILE" -ForegroundColor Green
    Write-Host "  +----------------------------------------------+"
    Write-Host ""

    return $arch
}

# ─── Pre-Installation Check ──────────────────────────────────────

function Check-Existing {
    Print-Step "2" "Scanning for Already-Installed Tools"

    Write-Host ""
    Write-Host "  Checking what's already on your system..." -ForegroundColor White
    Write-Host ""

    $script:MISSING_COUNT = 0
    $script:INSTALLED_COUNT = 0

    # ── Git ──
    Write-Host "  +-- Core Utilities -----------------------------------------------+" -ForegroundColor Cyan
    $ver = ""
    try {
        $ver = (git --version 2>$null)
        if ($ver) { $script:HAS_GIT = $true }
    } catch {}
    Status-Row "Git for Windows" $ver $script:HAS_GIT
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Java ──
    Write-Host "  +-- Java Runtime -------------------------------------------------+" -ForegroundColor Cyan
    $ver = ""
    try {
        $ver = (java -version 2>&1 | Select-Object -First 1)
        if ($ver) { $script:HAS_JAVA = $true }
    } catch {}
    Status-Row "Java JDK 17" $ver $script:HAS_JAVA
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Visual Studio ──
    Write-Host "  +-- Windows Build Tools ------------------------------------------+" -ForegroundColor Cyan
    $ver = ""
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        $vsInstalls = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property displayName 2>$null
        if ($vsInstalls) {
            $script:HAS_VS_CPP = $true
            $ver = ($vsInstalls | Select-Object -First 1)
        }
    }
    Status-Row "Visual Studio (C++ Desktop)" $ver $script:HAS_VS_CPP
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Flutter & Dart ──
    Write-Host "  +-- Flutter SDK --------------------------------------------------+" -ForegroundColor Cyan
    $ver = ""
    if (Test-Path "$FLUTTER_DIR\bin\flutter.bat") {
        $script:HAS_FLUTTER = $true
        try { $ver = (& "$FLUTTER_DIR\bin\flutter.bat" --version 2>$null | Select-Object -First 1) } catch { $ver = "installed @ $FLUTTER_DIR" }
    } elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
        $script:HAS_FLUTTER = $true
        try { $ver = (flutter --version 2>$null | Select-Object -First 1) } catch { $ver = "installed" }
    }
    Status-Row "Flutter SDK" $ver $script:HAS_FLUTTER

    $ver = ""
    if (Test-Path "$FLUTTER_DIR\bin\cache\dart-sdk\bin\dart.exe") {
        $script:HAS_DART = $true
        try { $ver = (& "$FLUTTER_DIR\bin\cache\dart-sdk\bin\dart.exe" --version 2>&1 | Select-Object -First 1) } catch { $ver = "installed" }
    } elseif (Get-Command dart -ErrorAction SilentlyContinue) {
        $script:HAS_DART = $true
        try { $ver = (dart --version 2>&1 | Select-Object -First 1) } catch { $ver = "installed" }
    }
    Status-Row "Dart SDK (bundled)" $ver $script:HAS_DART
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Android SDK ──
    Write-Host "  +-- Android SDK --------------------------------------------------+" -ForegroundColor Cyan

    $ver = ""
    if (Test-Path "$ANDROID_SDK_DIR\cmdline-tools\latest\bin\sdkmanager.bat") {
        $script:HAS_ANDROID_CMDLINE = $true; $ver = "$ANDROID_SDK_DIR\cmdline-tools\latest"
    } elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat")) {
        $script:HAS_ANDROID_CMDLINE = $true; $ver = "$env:ANDROID_HOME\cmdline-tools\latest"
    }
    Status-Row "Android Command-Line Tools" $ver $script:HAS_ANDROID_CMDLINE

    $ver = ""
    if (Test-Path "$ANDROID_SDK_DIR\platform-tools\adb.exe") {
        $script:HAS_ANDROID_PLATFORM_TOOLS = $true; $ver = "$ANDROID_SDK_DIR\platform-tools"
    } elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) {
        $script:HAS_ANDROID_PLATFORM_TOOLS = $true; $ver = "$env:ANDROID_HOME\platform-tools"
    }
    Status-Row "Android Platform Tools" $ver $script:HAS_ANDROID_PLATFORM_TOOLS

    $ver = ""
    if (Test-Path "$ANDROID_SDK_DIR\build-tools\$ANDROID_BUILD_TOOLS_VERSION") {
        $script:HAS_ANDROID_BUILD_TOOLS = $true; $ver = "v$ANDROID_BUILD_TOOLS_VERSION"
    } elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\build-tools\$ANDROID_BUILD_TOOLS_VERSION")) {
        $script:HAS_ANDROID_BUILD_TOOLS = $true; $ver = "v$ANDROID_BUILD_TOOLS_VERSION"
    }
    Status-Row "Android Build Tools" $ver $script:HAS_ANDROID_BUILD_TOOLS

    $ver = ""
    if (Test-Path "$ANDROID_SDK_DIR\platforms\android-$ANDROID_API_LEVEL") {
        $script:HAS_ANDROID_PLATFORM = $true; $ver = "API $ANDROID_API_LEVEL"
    } elseif ($env:ANDROID_HOME -and (Test-Path "$env:ANDROID_HOME\platforms\android-$ANDROID_API_LEVEL")) {
        $script:HAS_ANDROID_PLATFORM = $true; $ver = "API $ANDROID_API_LEVEL"
    }
    Status-Row "Android Platform" $ver $script:HAS_ANDROID_PLATFORM

    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # ── Environment Variables ──
    Write-Host "  +-- Environment Variables ----------------------------------------+" -ForegroundColor Cyan
    $ver = ""
    $existingFlutterHome = [Environment]::GetEnvironmentVariable("FLUTTER_HOME", "User")
    if ($existingFlutterHome) {
        $script:HAS_ENV_CONFIGURED = $true; $ver = "FLUTTER_HOME = $existingFlutterHome"
    }
    Status-Row "User env (FLUTTER_HOME, etc.)" $ver $script:HAS_ENV_CONFIGURED
    Write-Host "  +----------------------------------------------------------------+" -ForegroundColor Cyan

    # ── Summary ──
    Write-Host ""
    Write-Host "  +----------------------------------------------+"
    Write-Host "  |  " -NoNewline; Write-Host "[OK] Already installed:   $($script:INSTALLED_COUNT)" -ForegroundColor Green
    Write-Host "  |  " -NoNewline; Write-Host "[--] Missing / to install: $($script:MISSING_COUNT)" -ForegroundColor Red
    Write-Host "  +----------------------------------------------+"
    Write-Host ""

    if ($script:MISSING_COUNT -eq 0) {
        Write-Host "  Everything is already installed!" -ForegroundColor Green
        Write-Host ""
        $confirm = Read-Host "  Run flutter doctor to verify? [Y/n]"
        if (-not $confirm -or $confirm -match '^[Yy]$') {
            Verify-Installation
        }
        Write-Host ""
        Write-Host "  Nothing to do. Exiting." -ForegroundColor DarkGray
        exit 0
    }

    $confirm = Read-Host "  Install the $($script:MISSING_COUNT) missing component(s)? [Y/n]"
    if ($confirm -and $confirm -notmatch '^[Yy]$') {
        Info "Installation cancelled by user."
        exit 0
    }
}

# ─── Install Git ──────────────────────────────────────────────────

function Install-GitForWindows {
    Print-Step "3a" "Git for Windows"

    if ($script:HAS_GIT) {
        Success "Git is already installed. Skipping."
        return
    }

    Info "Downloading Git for Windows..."
    $gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"

    Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstaller -UseBasicParsing
    Success "Git installer downloaded."

    Info "Installing Git silently..."
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS", "/COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait
    Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Success "Git for Windows installed successfully!"
    } else {
        Warn "Git installation may require a terminal restart."
    }
}

# ─── Install Java JDK ────────────────────────────────────────────

function Install-JavaJDK {
    Print-Step "3b" "Java JDK 17 (Adoptium Temurin)"

    if ($script:HAS_JAVA) {
        Success "Java JDK is already installed. Skipping."
        return
    }

    Info "Downloading Adoptium Temurin JDK 17..."
    $jdkUrl = "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
    $jdkInstaller = "$env:TEMP\temurin-jdk17-installer.msi"

    Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkInstaller -UseBasicParsing
    Success "JDK installer downloaded."

    Info "Installing JDK silently..."
    Start-Process msiexec.exe -ArgumentList "/i", "`"$jdkInstaller`"", "/qn", "ADDLOCAL=FeatureMain,FeatureJavaHome,FeatureEnvironment" -Wait
    Remove-Item $jdkInstaller -Force -ErrorAction SilentlyContinue

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    Success "Java JDK 17 installed."
}

# ─── Check Visual Studio ─────────────────────────────────────────

function Check-VisualStudio {
    Print-Step "3c" "Visual Studio / Build Tools"

    if ($script:HAS_VS_CPP) {
        Success "Visual Studio with C++ Desktop workload already installed. Skipping."
        return
    }

    Warn "Visual Studio with 'Desktop development with C++' workload NOT found."
    Write-Host ""
    Write-Host "  For Windows desktop Flutter development, you need Visual Studio" -ForegroundColor Yellow
    Write-Host "  with the 'Desktop development with C++' workload installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    Write-Host ""

    $downloadVS = Read-Host "  Would you like to download Visual Studio Build Tools now? [y/N]"
    if ($downloadVS -match '^[Yy]$') {
        Info "Downloading Visual Studio Build Tools..."
        $vsbtUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
        $vsbtInstaller = "$env:TEMP\vs_buildtools.exe"
        Invoke-WebRequest -Uri $vsbtUrl -OutFile $vsbtInstaller -UseBasicParsing
        Success "Downloaded VS Build Tools installer."
        Info "Launching installer... Please select 'Desktop development with C++' workload."
        Start-Process -FilePath $vsbtInstaller -ArgumentList "--add", "Microsoft.VisualStudio.Workload.NativeDesktop", "--includeRecommended", "--passive", "--norestart" -Wait
        Remove-Item $vsbtInstaller -Force -ErrorAction SilentlyContinue
        Success "Visual Studio Build Tools installation initiated."
    } else {
        Warn "Skipping Visual Studio. Windows desktop development will not be available."
    }
}

# ─── Install Flutter SDK ─────────────────────────────────────────

function Install-FlutterSDK {
    Print-Step "4" "Flutter SDK"

    if ($script:HAS_FLUTTER) {
        Success "Flutter SDK already installed. Skipping download."
        Info "Tip: run 'flutter upgrade' to update to the latest version."
        return
    }

    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null

    Info "Cloning Flutter SDK ($FLUTTER_CHANNEL channel)..."
    Info "This may take several minutes depending on your internet speed..."
    Write-Host ""

    git clone "https://github.com/flutter/flutter.git" -b $FLUTTER_CHANNEL $FLUTTER_DIR

    Success "Flutter SDK cloned to: $FLUTTER_DIR"

    $env:Path = "$FLUTTER_DIR\bin;$env:Path"

    Info "Running initial Flutter setup (downloading Dart SDK, tools)..."
    & "$FLUTTER_DIR\bin\flutter.bat" precache
    Success "Flutter pre-cache complete!"

    Write-Host ""
    & "$FLUTTER_DIR\bin\flutter.bat" --version
    Write-Host ""
}

# ─── Install Android SDK ─────────────────────────────────────────

function Install-AndroidSDK {
    Print-Step "5" "Android SDK (Command-Line Tools)"

    # If everything is already installed, skip
    if ($script:HAS_ANDROID_CMDLINE -and $script:HAS_ANDROID_PLATFORM_TOOLS -and `
        $script:HAS_ANDROID_BUILD_TOOLS -and $script:HAS_ANDROID_PLATFORM) {
        Success "Android SDK is fully installed. Skipping."
        return
    }

    New-Item -ItemType Directory -Path "$ANDROID_SDK_DIR\cmdline-tools" -Force | Out-Null

    # Install cmdline-tools if missing
    if (-not $script:HAS_ANDROID_CMDLINE) {
        $cmdlineZip = "commandlinetools-win-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip"
        $downloadUrl = "https://dl.google.com/android/repository/$cmdlineZip"
        $tmpZip = "$env:TEMP\$cmdlineZip"

        Info "Downloading Android Command-Line Tools..."
        Item "URL: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpZip -UseBasicParsing
        Success "Download complete."

        Info "Extracting..."
        $extractPath = "$env:TEMP\android-cmdline-tools-extract"
        Expand-Archive -Path $tmpZip -DestinationPath $extractPath -Force

        if (Test-Path "$ANDROID_SDK_DIR\cmdline-tools\latest") {
            Remove-Item "$ANDROID_SDK_DIR\cmdline-tools\latest" -Recurse -Force
        }
        Move-Item "$extractPath\cmdline-tools" "$ANDROID_SDK_DIR\cmdline-tools\latest"
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
        Success "Android Command-Line Tools installed."
    } else {
        Success "Android Command-Line Tools already installed. Skipping."
    }

    $env:ANDROID_HOME = $ANDROID_SDK_DIR
    $env:Path = "$ANDROID_SDK_DIR\cmdline-tools\latest\bin;$ANDROID_SDK_DIR\platform-tools;$env:Path"

    # Only install missing SDK components
    $sdkPackages = @()
    if (-not $script:HAS_ANDROID_PLATFORM_TOOLS) { $sdkPackages += "platform-tools" }
    if (-not $script:HAS_ANDROID_PLATFORM)       { $sdkPackages += "platforms;android-$ANDROID_API_LEVEL" }
    if (-not $script:HAS_ANDROID_BUILD_TOOLS)    { $sdkPackages += "build-tools;$ANDROID_BUILD_TOOLS_VERSION" }

    $sdkmanager = "$ANDROID_SDK_DIR\cmdline-tools\latest\bin\sdkmanager.bat"

    if ($sdkPackages.Count -gt 0) {
        Info "Installing missing Android SDK components:"
        foreach ($pkg in $sdkPackages) {
            Item $pkg
        }
        Write-Host ""

        & $sdkmanager --sdk_root="$ANDROID_SDK_DIR" @sdkPackages
        Success "Android SDK components installed!"
    } else {
        Success "All Android SDK components already installed. Skipping."
    }

    Info "Accepting Android SDK licenses..."
    echo "y`ny`ny`ny`ny`ny`ny`ny`n" | & $sdkmanager --sdk_root="$ANDROID_SDK_DIR" --licenses 2>$null
    Success "Android licenses accepted."
}

# ─── Configure Environment Variables ─────────────────────────────

function Configure-Environment {
    Print-Step "6" "Configuring Environment Variables (User-level)"

    if ($script:HAS_ENV_CONFIGURED) {
        Success "Environment variables already configured. Skipping."
        Info "If paths have changed, clear FLUTTER_HOME/ANDROID_HOME in User env and re-run."
    } else {
        [Environment]::SetEnvironmentVariable("FLUTTER_HOME", $FLUTTER_DIR, "User")
        Success "Set FLUTTER_HOME = $FLUTTER_DIR"

        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $ANDROID_SDK_DIR, "User")
        Success "Set ANDROID_HOME = $ANDROID_SDK_DIR"

        [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $ANDROID_SDK_DIR, "User")
        Success "Set ANDROID_SDK_ROOT = $ANDROID_SDK_DIR"

        # Update PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $pathsToAdd = @(
            "$FLUTTER_DIR\bin",
            "$FLUTTER_DIR\bin\cache\dart-sdk\bin",
            "$ANDROID_SDK_DIR\cmdline-tools\latest\bin",
            "$ANDROID_SDK_DIR\platform-tools",
            "$ANDROID_SDK_DIR\build-tools\$ANDROID_BUILD_TOOLS_VERSION"
        )

        $pathModified = $false
        foreach ($pathEntry in $pathsToAdd) {
            if ($currentPath -notlike "*$pathEntry*") {
                $currentPath = "$pathEntry;$currentPath"
                $pathModified = $true
                Item "Added to PATH: $pathEntry"
            } else {
                Item "Already in PATH: $pathEntry"
            }
        }

        if ($pathModified) {
            [Environment]::SetEnvironmentVariable("Path", $currentPath, "User")
            Success "User PATH updated."
        }
    }

    # Always update current session
    $env:FLUTTER_HOME = $FLUTTER_DIR
    $env:ANDROID_HOME = $ANDROID_SDK_DIR
    $env:ANDROID_SDK_ROOT = $ANDROID_SDK_DIR
    $pathsToAdd = @(
        "$FLUTTER_DIR\bin",
        "$FLUTTER_DIR\bin\cache\dart-sdk\bin",
        "$ANDROID_SDK_DIR\cmdline-tools\latest\bin",
        "$ANDROID_SDK_DIR\platform-tools",
        "$ANDROID_SDK_DIR\build-tools\$ANDROID_BUILD_TOOLS_VERSION"
    )
    $env:Path = ($pathsToAdd -join ";") + ";$env:Path"

    Write-Host ""
    Write-Host "  Active Environment:" -ForegroundColor White
    Write-Host "  +--------------------------------------------------------------+"
    Write-Host "  |  FLUTTER_HOME    = " -NoNewline; Write-Host "$FLUTTER_DIR" -ForegroundColor Green
    Write-Host "  |  ANDROID_HOME    = " -NoNewline; Write-Host "$ANDROID_SDK_DIR" -ForegroundColor Green
    Write-Host "  |  ANDROID_SDK_ROOT= " -NoNewline; Write-Host "$ANDROID_SDK_DIR" -ForegroundColor Green
    Write-Host "  |  PATH additions:"
    foreach ($p in $pathsToAdd) {
        Write-Host "  |    + $p" -ForegroundColor DarkGray
    }
    Write-Host "  +--------------------------------------------------------------+"
    Write-Host ""
}

# ─── Configure Flutter ────────────────────────────────────────────

function Configure-Flutter {
    Print-Step "7" "Configuring Flutter"

    Info "Setting Android SDK path in Flutter..."
    & "$FLUTTER_DIR\bin\flutter.bat" config --android-sdk $ANDROID_SDK_DIR 2>$null
    Success "Android SDK configured in Flutter."

    Info "Accepting Android licenses via Flutter..."
    echo "y`ny`ny`ny`ny`ny`ny`n" | & "$FLUTTER_DIR\bin\flutter.bat" doctor --android-licenses 2>$null
    Success "Licenses accepted."
}

# ─── Verify Installation ─────────────────────────────────────────

function Verify-Installation {
    Print-Step "8" "Verifying Installation (flutter doctor)"

    Write-Host ""
    & "$FLUTTER_DIR\bin\flutter.bat" doctor -v
    Write-Host ""
}

# ─── Final Summary ───────────────────────────────────────────────

function Print-Summary {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                           ║" -ForegroundColor Green
    Write-Host "  ║        Setup Complete!                                     ║" -ForegroundColor Green
    Write-Host "  ║                                                           ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Quick Start:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Restart your terminal (or open a new PowerShell window)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Create a new Flutter project:" -ForegroundColor Cyan
    Write-Host "     flutter create my_app" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  3. Run your app:" -ForegroundColor Cyan
    Write-Host "     cd my_app; flutter run" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  4. Check setup anytime:" -ForegroundColor Cyan
    Write-Host "     flutter doctor" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Installed Locations:" -ForegroundColor White
    Write-Host "     Flutter SDK:    " -NoNewline; Write-Host "$FLUTTER_DIR" -ForegroundColor Green
    Write-Host "     Android SDK:    " -NoNewline; Write-Host "$ANDROID_SDK_DIR" -ForegroundColor Green
    Write-Host ""
    Write-Host "  NOTE: For Windows desktop dev, ensure Visual Studio" -ForegroundColor Yellow
    Write-Host "  with 'Desktop development with C++' workload is installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Script completed at: $(Get-Date)" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Main ─────────────────────────────────────────────────────────

Print-Banner
Check-Prerequisites
$arch = Detect-System
Check-Existing              # ← scans everything, shows status, asks to proceed
Install-GitForWindows       # ← skips if already installed
Install-JavaJDK             # ← skips if already installed
Check-VisualStudio          # ← skips if already installed
Install-FlutterSDK          # ← skips if already installed
Install-AndroidSDK          # ← skips installed components
Configure-Environment       # ← skips if already configured
Configure-Flutter
Verify-Installation
Print-Summary
