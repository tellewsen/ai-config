#Requires -Version 5.1
# install.ps1 — Windows native installer for ai-config
# Creates a symlink for CLAUDE.md and copies agents with path substitution.
# Requires Developer Mode enabled (Settings > For Developers > Developer Mode)
# OR run as Administrator for symlink creation.
# Safe to re-run: backs up existing files, skips existing symlinks.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$AgentsDir = Join-Path $ClaudeDir 'agents'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Write-Info  { param($msg) Write-Host "[info] $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[ok]   $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[warn] $msg" -ForegroundColor Yellow }

# ── 1. Create directories ────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $AgentsDir | Out-Null
Write-Info "Ensured $AgentsDir exists"

# ── 2. Symlink CLAUDE.md ─────────────────────────────────────────────────────
$ClaudeMdTarget = Join-Path $ClaudeDir 'CLAUDE.md'
$ClaudeMdSrc    = Join-Path $RepoDir 'claude\CLAUDE.md'

$isSymlink = (Get-Item $ClaudeMdTarget -ErrorAction SilentlyContinue)?.LinkType -eq 'SymbolicLink'

if ($isSymlink) {
    Write-Ok "CLAUDE.md already symlinked — skipping"
} elseif (Test-Path $ClaudeMdTarget) {
    $backup = "$ClaudeMdTarget.bak.$Timestamp"
    Write-Warn "Backing up existing CLAUDE.md → $backup"
    Move-Item $ClaudeMdTarget $backup
    try {
        cmd /c mklink "$ClaudeMdTarget" "$ClaudeMdSrc" | Out-Null
        Write-Ok "Linked CLAUDE.md"
    } catch {
        Write-Warn "Symlink failed (need Developer Mode or Admin). Copying instead."
        Copy-Item $ClaudeMdSrc $ClaudeMdTarget
        Write-Ok "Copied CLAUDE.md (not symlinked — edits won't auto-sync)"
    }
} else {
    try {
        cmd /c mklink "$ClaudeMdTarget" "$ClaudeMdSrc" | Out-Null
        Write-Ok "Linked CLAUDE.md"
    } catch {
        Write-Warn "Symlink failed (need Developer Mode or Admin). Copying instead."
        Copy-Item $ClaudeMdSrc $ClaudeMdTarget
        Write-Ok "Copied CLAUDE.md (not symlinked — edits won't auto-sync)"
    }
}

# ── 3. Copy agents with path substitution ────────────────────────────────────
Write-Host ""
Write-Info "Installing agents..."

$HomeDir = $env:USERPROFILE -replace '\\', '\\'

Get-ChildItem (Join-Path $RepoDir 'claude\agents\*.md') | ForEach-Object {
    $src  = $_.FullName
    $dst  = Join-Path $AgentsDir $_.Name

    # Expand $HOME placeholder — on Windows Claude uses USERPROFILE
    $content = Get-Content $src -Raw
    $content = $content -replace '\$HOME', $env:USERPROFILE.Replace('\', '\\')
    Set-Content -Path $dst -Value $content -Encoding UTF8
    Write-Ok "Installed agent: $($_.Name)"
}

# ── 4. Copy settings.template.json if settings.json is absent ────────────────
Write-Host ""
$SettingsTarget = Join-Path $ClaudeDir 'settings.json'
$SettingsSrc    = Join-Path $RepoDir 'claude\settings.template.json'

if (-not (Test-Path $SettingsTarget)) {
    Copy-Item $SettingsSrc $SettingsTarget
    Write-Ok "Copied settings.template.json → settings.json"
} else {
    Write-Info "settings.json already exists — not overwriting"
}

# ── 5. Set up project memory for this repo ───────────────────────────────────
# Claude Code encodes paths: replace path separators with -
Write-Host ""
$EncodedPath = $RepoDir -replace '[/\\]', '-'
# Ensure it starts with - (for absolute paths on Windows starting with drive letter)
if (-not $EncodedPath.StartsWith('-')) { $EncodedPath = "-$EncodedPath" }
$MemoryDir  = Join-Path $ClaudeDir "projects\$EncodedPath\memory"
$MemoryFile = Join-Path $MemoryDir 'MEMORY.md'

New-Item -ItemType Directory -Force -Path $MemoryDir | Out-Null

if (-not (Test-Path $MemoryFile)) {
    $content = Get-Content (Join-Path $RepoDir 'memory\MEMORY.template.md') -Raw
    $content = $content -replace '\$HOME', $env:USERPROFILE
    $content = $content -replace '\$REPO_DIR', $RepoDir
    Set-Content -Path $MemoryFile -Value $content -Encoding UTF8
    Write-Ok "Created memory at $MemoryFile"
} else {
    Write-Info "Memory file already exists — not overwriting"
}

# ── 6. Done ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Ok "Installation complete."
Write-Host ""
Write-Host "  CLAUDE.md: $ClaudeMdTarget"
Write-Host "  Agents:    $AgentsDir"
Write-Host "  Memory:    $MemoryFile"
Write-Host ""
Write-Host "  To use Copilot instructions in a project:"
Write-Host "    Copy $RepoDir\copilot\copilot-instructions.md to <project>\.github\copilot-instructions.md"
Write-Host ""
Write-Host "  To update agents after repo changes: re-run this script."
