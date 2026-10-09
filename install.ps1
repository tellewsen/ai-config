#Requires -Version 5.1
# install.ps1 - Windows native installer for ai-config
# Symlinks CLAUDE.md and installs the core plugin (agents, skills, hooks) from this
# repo's marketplace. Also migrates machines set up before the plugin existed.
# Symlinks need Developer Mode (Settings > For Developers) or an Administrator shell.
# Safe to re-run.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

function Write-Info  { param($msg) Write-Host "[info] $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[ok]   $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[warn] $msg" -ForegroundColor Yellow }

New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

# -- 1. Symlink CLAUDE.md -----------------------------------------------------
$ClaudeMdTarget = Join-Path $ClaudeDir 'CLAUDE.md'
$ClaudeMdSrc    = Join-Path $RepoDir 'claude\CLAUDE.md'

$existing  = Get-Item $ClaudeMdTarget -ErrorAction SilentlyContinue
$isSymlink = $existing -and $existing.LinkType -eq 'SymbolicLink'

if ($isSymlink) {
    Write-Ok "CLAUDE.md already symlinked - skipping"
} else {
    if ($existing) {
        $backup = "$ClaudeMdTarget.bak.$Timestamp"
        Write-Warn "Backing up existing CLAUDE.md -> $backup"
        Move-Item $ClaudeMdTarget $backup
    }
    try {
        New-Item -ItemType SymbolicLink -Path $ClaudeMdTarget -Target $ClaudeMdSrc | Out-Null
        Write-Ok "Linked CLAUDE.md"
    } catch {
        Write-Warn "Symlink failed (need Developer Mode or Admin). Copying instead."
        Copy-Item $ClaudeMdSrc $ClaudeMdTarget
        Write-Ok "Copied CLAUDE.md (not symlinked - edits won't auto-sync)"
    }
}

# -- 2. Migrate from the pre-plugin layout ------------------------------------
# Agents used to be copied into ~/.claude/agents. Left in place they would
# duplicate the plugin's namespaced core:<name> versions.
Write-Host ""
Get-ChildItem (Join-Path $RepoDir 'plugins\core\agents\*.md') | ForEach-Object {
    $name = $_.BaseName

    $oldAgent = Join-Path $ClaudeDir "agents\$name.md"
    if (Test-Path $oldAgent) {
        Remove-Item $oldAgent
        Write-Ok "Removed old agent copy: $name (now core:$name)"
    }

    # Plugin agents keep memory under core-<name>; carry existing memories over.
    $oldMem = Join-Path $ClaudeDir "agent-memory\$name"
    $newMem = Join-Path $ClaudeDir "agent-memory\core-$name"
    if (Test-Path $oldMem) {
        if (Test-Path $newMem) {
            Write-Warn "Both agent-memory\$name and agent-memory\core-$name exist - merge by hand"
        } else {
            Move-Item $oldMem $newMem
            Write-Ok "Moved agent memory: $name -> core-$name"
        }
    }
}

# Retired in favor of the built-in /code-review and /security-review.
foreach ($name in 'code-reviewer', 'security-auditor') {
    $oldAgent = Join-Path $ClaudeDir "agents\$name.md"
    if (Test-Path $oldAgent) {
        Remove-Item $oldAgent
        Write-Ok "Removed retired agent: $name"
    }
}

# -- 3. Copy settings.template.json if settings.json is absent ----------------
Write-Host ""
$SettingsTarget = Join-Path $ClaudeDir 'settings.json'
$SettingsSrc    = Join-Path $RepoDir 'claude\settings.template.json'

if (-not (Test-Path $SettingsTarget)) {
    Copy-Item $SettingsSrc $SettingsTarget
    Write-Ok "Copied settings.template.json -> settings.json"
} else {
    Write-Info "settings.json already exists - not overwriting"
    Write-Info "  Make sure it enables core@ai-config and sets autoUpdate on the ai-config marketplace (see claude\settings.template.json)"
}

# -- 4. Install the core plugin -----------------------------------------------
Write-Host ""
if (Get-Command claude -ErrorAction SilentlyContinue) {
    # PowerShell 5.1 turns redirected native stderr into errors, which Stop would make
    # fatal even when claude succeeds; judge by exit code instead.
    $ErrorActionPreference = 'Continue'
    & claude plugin marketplace add tellewsen/ai-config *> $null
    & claude plugin install core@ai-config *> $null
    $installed = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if ($installed) {
        Write-Ok "Installed plugin core@ai-config"
    } else {
        Write-Warn "Plugin install failed - run: claude plugin install core@ai-config"
    }
} else {
    Write-Warn "claude not found - after installing Claude Code run: claude plugin install core@ai-config"
}

# -- 5. Set up project memory for this repo -----------------------------------
# Claude Code names the folder after the absolute path with every character that
# isn't a letter or digit replaced by -, so C:\Users\me\ai-config is C--Users-me-ai-config
Write-Host ""
$EncodedPath = $RepoDir -replace '[^a-zA-Z0-9]', '-'
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
    Write-Info "Memory file already exists - not overwriting"
}

# -- 6. Done -------------------------------------------------------------------
Write-Host ""
Write-Ok "Installation complete."
Write-Host ""
Write-Host "  CLAUDE.md: $ClaudeMdTarget"
Write-Host "  Plugin:    core@ai-config (agents core:<name>, skills /core:<name>), auto-updates"
Write-Host "  Memory:    $MemoryFile"
Write-Host ""
Write-Host "  To use Copilot instructions in a project:"
Write-Host "    Copy $RepoDir\copilot\copilot-instructions.md to <project>\.github\copilot-instructions.md"
