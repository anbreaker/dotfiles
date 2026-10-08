#Requires -Version 5.1
<#
    Windows equivalent of install.sh.
    Sets up the PowerShell prompt stack (Oh My Posh + PSReadLine + posh-git),
    a Nerd Font, Windows Terminal colors, and Herdr (Windows beta).

    Run from an elevated-or-normal PowerShell:
        Set-ExecutionPolicy -Scope Process Bypass -Force
        .\windows\install.ps1
#>

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing Windows dotfiles..." -ForegroundColor Cyan

# --- winget must be present (ships with modern Windows via 'App Installer') ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

function Install-WingetPackage([string]$Id) {
    $found = winget list --id $Id -e --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id
    if ($found) { Write-Host "  $Id already installed"; return }
    Write-Host "  installing $Id..."
    winget install -e --id $Id --accept-source-agreements --accept-package-agreements
}

# --- core packages ---
Install-WingetPackage 'Microsoft.PowerShell'
Install-WingetPackage 'Microsoft.WindowsTerminal'
Install-WingetPackage 'Git.Git'
Install-WingetPackage 'JanDeDobbeleer.OhMyPosh'
Install-WingetPackage 'jqlang.jq'

# refresh PATH so freshly installed tools are callable in this session
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# --- Nerd Font (MesloLGS) via Oh My Posh ---
# `oh-my-posh font install` registers per-user fonts under HKCU, not HKLM, so check that key
# directly (fast, no external process) instead of always re-running the installer: its
# progress-bar/spinner UI can take several minutes to release control when stdout isn't a
# real console (e.g. run through an automation harness), so skip it once the font is present.
$fontsKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$mesloInstalled = (Get-ItemProperty -Path $fontsKey -ErrorAction SilentlyContinue).PSObject.Properties.Name -like 'MesloLGS*'
if ($mesloInstalled) {
    Write-Host "MesloLGS Nerd Font already installed"
} elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Host "Installing MesloLGS Nerd Font..."
    oh-my-posh font install Meslo
} else {
    Write-Warning "oh-my-posh not on PATH yet; open a new terminal and run: oh-my-posh font install Meslo"
}

# --- PowerShell modules ---
# Bootstrap the NuGet provider non-interactively first: on a stock Windows PowerShell 5.1
# install (PowerShellGet 1.0.0.1), the first Install-Module call prompts "Install NuGet
# provider now? [Y/N]" and -Force does NOT suppress it, which hangs forever in a
# non-interactive shell.
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
}
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
# PSReadLine needs its own version check (not just presence): Windows PowerShell 5.1 ships
# PSReadLine 2.0.0 out of the box, which the profile's -PredictionSource/-PredictionViewStyle
# calls need 2.2.0+ for (Predictive IntelliSense). A plain "is it installed" check would see
# the bundled 2.0.0 and skip installing a newer one.
$psreadline = Get-Module -ListAvailable PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
if (-not $psreadline -or $psreadline.Version -lt [Version]'2.2.0') {
    Write-Host "Installing/updating PSReadLine..."
    Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
}
foreach ($mod in 'posh-git', 'Terminal-Icons') {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "Installing module $mod..."
        Install-Module $mod -Scope CurrentUser -Force -AllowClobber
    }
}

# --- PowerShell profile (symlink to repo; fall back to copy without Developer Mode) ---
$profileSrc = Join-Path $scriptDir 'Microsoft.PowerShell_profile.ps1'
$profileDst = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path -Parent $profileDst
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

if ((Test-Path $profileDst) -and -not (Get-Item $profileDst).LinkType) {
    Write-Host "Backing up existing profile to $profileDst.backup"
    Copy-Item $profileDst "$profileDst.backup" -Force
}
try {
    New-Item -ItemType SymbolicLink -Path $profileDst -Target $profileSrc -Force -ErrorAction Stop | Out-Null
    Write-Host "Linked profile -> $profileSrc"
} catch {
    Copy-Item $profileSrc $profileDst -Force
    Write-Host "Copied profile (symlink needs Developer Mode/admin) -> $profileDst"
}

# --- Windows Terminal: font + color scheme (mirrors the Ghostty palette) ---
function Update-WindowsTerminal {
    $candidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $settingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $settingsPath) {
        Write-Warning "Windows Terminal settings.json not found; open Windows Terminal once, then re-run."
        return
    }

    Copy-Item $settingsPath "$settingsPath.backup" -Force

    try {
        # Windows Terminal ships settings.json as JSONC (e.g. "// Add custom color schemes to
        # this array."). PowerShell 5.1's ConvertFrom-Json has zero JSONC tolerance and throws
        # on any comment, so strip // and /* */ comments while leaving string literals (URLs
        # like "https://aka.ms/...") untouched.
        $raw = Get-Content $settingsPath -Raw
        $noComments = [regex]::Replace(
            $raw,
            '"(?:\\.|[^"\\])*"|(?<comment>//[^\r\n]*|/\*[\s\S]*?\*/)',
            { param($m) if ($m.Groups['comment'].Success) { '' } else { $m.Value } }
        )
        $json = $noComments | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse Windows Terminal settings.json ($($_.Exception.Message)); skipping terminal patch."
        return
    }

    $scheme = [ordered]@{
        name = 'BasicDotfiles'; background = '#071B22'; foreground = '#7C8B8D'
        cursorColor = '#9C9A9C'; selectionBackground = '#7C8B8D'
        black = '#000000'; red = '#990000'; green = '#72A52E'; yellow = '#96993D'
        blue = '#2B8BD2'; purple = '#AF6CB0'; cyan = '#6FB2A9'; white = '#BFBFBF'
        brightBlack = '#666666'; brightRed = '#E52F31'; brightGreen = '#67D85D'; brightYellow = '#E6E45A'
        brightBlue = '#5255FE'; brightPurple = '#CF63E5'; brightCyan = '#93E6E4'; brightWhite = '#E5E5E5'
    }

    if (-not ($json.PSObject.Properties.Name -contains 'schemes')) {
        $json | Add-Member -NotePropertyName schemes -NotePropertyValue @()
    }
    $json.schemes = @($json.schemes | Where-Object { $_.name -ne 'BasicDotfiles' }) + ([pscustomobject]$scheme)

    if (-not ($json.PSObject.Properties.Name -contains 'profiles')) {
        $json | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{})
    }
    if (-not ($json.profiles.PSObject.Properties.Name -contains 'defaults')) {
        $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $defaults = $json.profiles.defaults
    # oh-my-posh's Windows font package registers full Nerd Fonts names, not the short "MesloLGS NF"
    # alias from the macOS Homebrew cask; "Mono" is the variant Nerd Fonts recommends for
    # grid-based terminals (icon glyphs forced to one cell width, matching Windows Terminal's model).
    $font = [pscustomobject]@{ face = 'MesloLGS Nerd Font Mono' }
    if ($defaults.PSObject.Properties.Name -contains 'font') { $defaults.font = $font }
    else { $defaults | Add-Member -NotePropertyName font -NotePropertyValue $font }
    if ($defaults.PSObject.Properties.Name -contains 'colorScheme') { $defaults.colorScheme = 'BasicDotfiles' }
    else { $defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue 'BasicDotfiles' }

    try {
        $json | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding utf8
        Write-Host "Windows Terminal patched (font=MesloLGS Nerd Font Mono, scheme=BasicDotfiles); backup at $settingsPath.backup"
    } catch {
        Write-Warning "Could not write Windows Terminal settings.json ($($_.Exception.Message)); restoring backup."
        Copy-Item "$settingsPath.backup" $settingsPath -Force
    }
}
Update-WindowsTerminal

# --- Herdr (Windows beta) ---
if (-not (Get-Command herdr -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Herdr (Windows beta)..."
    Invoke-RestMethod https://herdr.dev/install.ps1 | Invoke-Expression
} else {
    Write-Host "  herdr already installed"
}

# --- Herdr config + plugins (UNTESTED on Windows) ---
# Everything below is optional and was NOT run on a real Windows machine. Plugins ask for consent
# (default No) and are skipped when the session is non-interactive.
function Test-Interactive {
    [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

function Read-YesNo([string]$Prompt) {
    if (-not (Test-Interactive)) { return $false }
    (Read-Host "$Prompt [y/N]") -match '^[Yy]'
}

if (Get-Command herdr -ErrorAction SilentlyContinue) {
    # Assumption: Herdr reads $HOME\.config\herdr on Windows as well (same layout as macOS/Linux).
    # Adjust herdrConfigDir if the Windows beta uses a different location (e.g. %APPDATA%).
    $herdrConfigDir = Join-Path $HOME '.config\herdr'
    $herdrConfigSrc = Join-Path $scriptDir '..\herdr\config.toml'
    $herdrConfigDst = Join-Path $herdrConfigDir 'config.toml'
    New-Item -ItemType Directory -Path $herdrConfigDir -Force | Out-Null
    if ((Test-Path $herdrConfigDst) -and -not (Get-Item $herdrConfigDst).LinkType) {
        Write-Host "Backing up existing $herdrConfigDst to $herdrConfigDst.backup"
        Copy-Item $herdrConfigDst "$herdrConfigDst.backup" -Force
    }
    try {
        New-Item -ItemType SymbolicLink -Path $herdrConfigDst -Target $herdrConfigSrc -Force -ErrorAction Stop | Out-Null
        Write-Host "Linked Herdr config -> $herdrConfigSrc"
    } catch {
        Copy-Item $herdrConfigSrc $herdrConfigDst -Force
        Write-Host "Copied Herdr config (symlink needs Developer Mode/admin) -> $herdrConfigDst"
    }

    function Install-HerdrPlugin([string]$Label, [string]$Repo, [string]$Ref) {
        $cmd = "herdr plugin install $Repo --ref $Ref"
        if ((herdr plugin list 2>$null) -match [regex]::Escape("github:$Repo@")) {
            Write-Host "  Herdr plugin $Label already installed"; return
        }
        if (Read-YesNo "Install Herdr plugin $Label via '$cmd'?") {
            & herdr plugin install $Repo --ref $Ref
            if ($LASTEXITCODE -ne 0) { Write-Warning "Herdr plugin $Label install failed; run: $cmd" }
        } else {
            Write-Host "Skipping Herdr plugin $Label. Install it manually with: $cmd"
        }
    }

    # auto-title builds from source, so it needs Go.
    $autoTitleCmd = 'herdr plugin install kryptamine/herdr-auto-title --ref 899ee4e4c827129c9920c105f250628ff967ca98'
    $autoTitleInstalled = (herdr plugin list 2>$null) -match 'github:kryptamine/herdr-auto-title@'
    if (-not $autoTitleInstalled -and -not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Host "The Herdr auto-title plugin needs Go to build."
        if (Read-YesNo "Install Go via 'winget install -e --id GoLang.Go'?") {
            Install-WingetPackage 'GoLang.Go'
            if ($LASTEXITCODE -ne 0) { Write-Warning "Go install failed; run: winget install -e --id GoLang.Go" }
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [Environment]::GetEnvironmentVariable('Path', 'User')
        } else {
            Write-Host "Skipping Go. Install it manually with: winget install -e --id GoLang.Go"
        }
    }
    if ($autoTitleInstalled -or (Get-Command go -ErrorAction SilentlyContinue)) {
        Install-HerdrPlugin 'auto-title (automatic tab titles)' 'kryptamine/herdr-auto-title' '899ee4e4c827129c9920c105f250628ff967ca98'
    } else {
        Write-Host "Go not available: skipping Herdr plugin auto-title. After installing Go, run: $autoTitleCmd"
    }
    Install-HerdrPlugin 'reviewr (code review pane)' 'persiyanov/herdr-reviewr' '4c090225af706bf3aaa24b39fea890a72994f40f'
}

# --- Claude Code statusline (bash script; needs Git Bash, installed via Git.Git above) ---
# Git for Windows only adds Git\cmd to PATH (by design, to avoid shadowing other tools), so a
# bare "bash" on PATH resolves to Windows' WSL-launcher stub in System32, NOT Git Bash — that
# stub can't run this script (no WSL distro, or a foreign filesystem view even if there is one).
# Derive Git Bash's real bash.exe from git.exe's own location instead of trusting PATH.
$gitCmdPath = (Get-Command git -ErrorAction SilentlyContinue).Source
$bashExe = if ($gitCmdPath) { Join-Path (Split-Path (Split-Path $gitCmdPath)) 'bin\bash.exe' } else { $null }
if ($bashExe -and (Test-Path $bashExe)) {
    $claudeDir = Join-Path $HOME '.claude'
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null

    $statuslineSrc = Join-Path $scriptDir '..\claude\statusline.sh'
    $statuslineDst = Join-Path $claudeDir 'statusline.sh'
    if ((Test-Path $statuslineDst) -and -not (Get-Item $statuslineDst).LinkType) {
        Copy-Item $statuslineDst "$statuslineDst.backup" -Force
    }
    try {
        New-Item -ItemType SymbolicLink -Path $statuslineDst -Target $statuslineSrc -Force -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item $statuslineSrc $statuslineDst -Force
    }

    $settingsPath = Join-Path $claudeDir 'settings.json'
    try {
        $settings = if (Test-Path $settingsPath) {
            Copy-Item $settingsPath "$settingsPath.backup" -Force
            Get-Content $settingsPath -Raw | ConvertFrom-Json
        } else {
            [pscustomobject]@{}
        }
        # Both paths are quoted individually: bash.exe's own path contains a space ("Program Files").
        $statusLine = [pscustomobject]@{ type = 'command'; command = "`"$bashExe`" `"$statuslineDst`"" }
        if ($settings.PSObject.Properties.Name -contains 'statusLine') { $settings.statusLine = $statusLine }
        else { $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine }
        $settings | ConvertTo-Json -Depth 32 | Set-Content $settingsPath -Encoding utf8
        Write-Host "Claude Code statusline wired -> $settingsPath"
    } catch {
        Write-Warning "Could not wire Claude Code statusline into settings.json ($($_.Exception.Message))."
    }
} else {
    Write-Warning "Git Bash's bash.exe not found next to git.exe; the Claude Code statusline needs it. Re-run after Git.Git installs, or install manually."
}

Write-Host "Done! Open a new Windows Terminal tab (or run: . `$PROFILE)." -ForegroundColor Green
