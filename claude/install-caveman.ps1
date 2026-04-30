#requires -Version 5.1
<#
.SYNOPSIS
  Install Claude Code + caveman plugin on fresh Windows PC.
.DESCRIPTION
  Idempotent. Checks each step. Safe to re-run.
#>

[CmdletBinding()]
param(
    [string]$PluginRepo    = 'https://github.com/JuliusBrussee/caveman.git',
    [string]$PluginName    = 'caveman@caveman',
    [string]$MarketplaceId = 'caveman'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Step($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function OK($msg)    { Write-Host "  + $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Die($msg)   { Write-Host "  x $msg" -ForegroundColor Red; exit 1 }

# --- 1. git check ---
Step 'Check git'
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Die 'git not found. Install Git for Windows: https://git-scm.com/download/win then re-run.'
}
OK "git $(git --version)"

# --- 2. Install Claude Code if missing ---
Step 'Check Claude Code CLI'
$claudeBin  = Join-Path $env:USERPROFILE '.local\bin'
$claudeExe  = Join-Path $claudeBin 'claude.exe'

if (-not (Test-Path $claudeExe)) {
    Step 'Install Claude Code (native installer)'
    try {
        Invoke-RestMethod 'https://claude.ai/install.ps1' | Invoke-Expression
    } catch {
        Die "Installer failed: $_"
    }
    if (-not (Test-Path $claudeExe)) {
        Die "claude.exe still missing after install at $claudeExe"
    }
    OK 'Claude Code installed'
} else {
    OK "claude.exe exists at $claudeExe"
}

# --- 3. PATH (permanent + current session) ---
Step 'Ensure PATH contains claude bin'
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike "*$claudeBin*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$claudeBin", 'User')
    OK 'Added to user PATH (permanent)'
} else {
    OK 'Already in user PATH'
}
if ($env:Path -notlike "*$claudeBin*") {
    $env:Path = "$env:Path;$claudeBin"
    OK 'Added to current session PATH'
}

# --- 4. Verify claude runs ---
Step 'Verify claude --version'
$ver = & $claudeExe --version 2>&1
if ($LASTEXITCODE -ne 0) { Die "claude --version failed: $ver" }
OK $ver

# --- 5. Clone plugin source to permanent location ---
$srcRoot = Join-Path $env:USERPROFILE '.claude\plugins\sources'
$srcDir  = Join-Path $srcRoot 'caveman'

Step 'Clone/update caveman source'
New-Item -ItemType Directory -Force -Path $srcRoot | Out-Null
if (Test-Path (Join-Path $srcDir '.git')) {
    Push-Location $srcDir
    try {
        git fetch --quiet
        git pull --ff-only --quiet
        OK "Updated $srcDir"
    } finally { Pop-Location }
} else {
    if (Test-Path $srcDir) {
        Die "$srcDir exists but not a git repo. Move/delete it and re-run."
    }
    git clone --quiet $PluginRepo $srcDir
    if (-not (Test-Path (Join-Path $srcDir '.claude-plugin'))) {
        Warn 'Cloned but .claude-plugin folder not found — repo layout may have changed'
    }
    OK "Cloned to $srcDir"
}

# --- 6. Marketplace add (idempotent) ---
Step 'Register marketplace'
$mpJson = Join-Path $env:USERPROFILE '.claude\plugins\known_marketplaces.json'
$alreadyRegistered = $false
if (Test-Path $mpJson) {
    try {
        $mp = Get-Content $mpJson -Raw | ConvertFrom-Json
        if ($mp.PSObject.Properties.Name -contains $MarketplaceId -or
            ($mp.extraKnownMarketplaces -and $mp.extraKnownMarketplaces.$MarketplaceId)) {
            $alreadyRegistered = $true
        }
    } catch { }
}

# Always re-add to refresh path. CLI is idempotent.
& $claudeExe plugin marketplace add $srcDir 2>&1 | Tee-Object -Variable mpOut | Out-Null
if ($LASTEXITCODE -ne 0 -and $mpOut -notmatch 'already') {
    Warn "marketplace add output: $mpOut"
}
OK 'Marketplace registered'

# --- 7. Plugin install ---
Step "Install plugin $PluginName"
& $claudeExe plugin install $PluginName 2>&1 | Tee-Object -Variable instOut | Out-Null
if ($LASTEXITCODE -ne 0 -and $instOut -notmatch 'already') {
    Die "plugin install failed: $instOut"
}
OK $instOut

# --- 8. Verify plugin enabled ---
Step 'Verify plugin enabled'
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $settings)) { Die 'settings.json not found' }
$cfg = Get-Content $settings -Raw | ConvertFrom-Json
if (-not $cfg.enabledPlugins.$PluginName) {
    Die "$PluginName not enabled in settings.json"
}
OK "$PluginName enabled (scope: user)"

# --- 9. Verify command files in cache ---
Step 'Verify cached command files'
$cmdDirs = Get-ChildItem -Path (Join-Path $env:USERPROFILE '.claude\plugins\cache\caveman') `
    -Recurse -Directory -Filter 'commands' -ErrorAction SilentlyContinue
$tomls = $cmdDirs | ForEach-Object { Get-ChildItem $_.FullName -Filter '*.toml' } | Select-Object -Unique Name
if ($tomls.Count -lt 1) { Die 'No command .toml files found in cache' }
OK ("Commands found: " + (($tomls.Name) -join ', '))

Write-Host ''
Write-Host 'DONE. Open new Claude Code session, type /caveman to use.' -ForegroundColor Green
