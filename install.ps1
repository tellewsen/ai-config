#Requires -Version 5.1
# install.ps1 - Windows native installer for ai-config
# Links the shared instruction files, installs the core plugin (agents, skills, hooks)
# from this repo's marketplace, and sets the settings it manages. Also migrates machines set up before the plugin existed.
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

# -- 1. Link instruction files ------------------------------------------------
# Links (not copies) so edits and pulls take effect immediately; copies are the
# fallback when symlinks aren't allowed.
function Link-File($src, $dst) {
    $label = $dst.Replace($env:USERPROFILE, '~')
    $item = Get-Item $dst -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'SymbolicLink' -and @($item.Target)[0] -eq $src) {
        Write-Ok "$label already linked - skipping"
        return
    }
    if ($item) {
        Write-Warn "Backing up existing $label -> $(Split-Path -Leaf $dst).bak.$Timestamp"
        Move-Item $dst "$dst.bak.$Timestamp"
    }
    try {
        New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
        Write-Ok "Linked $label"
    } catch {
        Copy-Item $src $dst
        Write-Warn "Copied $label - symlinks need Developer Mode or Admin; re-run after pulling to refresh it"
    }
}

Link-File (Join-Path $RepoDir 'claude\CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md')
# CLAUDE.md imports the shared rules from @~/.claude/AGENTS.md.
$SharedAgents = Join-Path $RepoDir 'shared\AGENTS.md'
Link-File $SharedAgents (Join-Path $ClaudeDir 'AGENTS.md')
# Other tools read the same file from their own home, when they are installed.
$CopilotDir = Join-Path $env:USERPROFILE '.copilot'
$CodexDir   = Join-Path $env:USERPROFILE '.codex'
if (Test-Path $CopilotDir) { Link-File $SharedAgents (Join-Path $CopilotDir 'copilot-instructions.md') }
if (Test-Path $CodexDir)   { Link-File $SharedAgents (Join-Path $CodexDir 'AGENTS.md') }

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

# -- 3. Install the core plugin -----------------------------------------------
# Before the settings step: `claude plugin` rewrites settings.json and drops keys it
# does not manage, such as the marketplace autoUpdate flag.
Write-Host ""
if (Get-Command claude -ErrorAction SilentlyContinue) {
    # PowerShell 5.1 turns redirected native stderr into errors, which Stop would make
    # fatal even when claude succeeds; judge by exit code instead.
    $ErrorActionPreference = 'Continue'
    $already = (& claude plugin list 2>$null | Out-String) -match 'core@ai-config'
    if (-not $already) {
        & claude plugin marketplace add tellewsen/ai-config *> $null
        & claude plugin install core@ai-config *> $null
        $installed = ($LASTEXITCODE -eq 0)
    }
    $ErrorActionPreference = 'Stop'
    if ($already) {
        Write-Ok "Plugin core@ai-config already installed - skipping"
    } elseif ($installed) {
        Write-Ok "Installed plugin core@ai-config"
    } else {
        Write-Warn "Plugin install failed - run: claude plugin install core@ai-config"
    }
} else {
    Write-Warn "claude not found - after installing Claude Code run: claude plugin install core@ai-config"
}

# -- 4. Settings --------------------------------------------------------------
# Copied from the template on a new machine. On every run, set what this repo
# manages: AI_CONFIG_DIR (the path skills and hooks use), the permissions
# allowlist, the core plugin, and marketplace auto-update. Hooks are left alone here; they need bash anyway.
Write-Host ""
$SettingsTarget = Join-Path $ClaudeDir 'settings.json'
$SettingsSrc    = Join-Path $RepoDir 'claude\settings.template.json'

function Set-Prop($obj, $name, $value) {
    if ($obj.PSObject.Properties[$name]) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}
function Get-OrAdd($obj, $name) {
    if (-not $obj.PSObject.Properties[$name]) { Set-Prop $obj $name ([pscustomobject]@{}) }
    return $obj.$name
}

$fresh = -not (Test-Path $SettingsTarget)
if ($fresh) {
    Copy-Item $SettingsSrc $SettingsTarget
    Write-Ok "Copied settings.template.json -> settings.json"
}
$raw = Get-Content $SettingsTarget -Raw -Encoding UTF8
$s = $raw | ConvertFrom-Json
$before = $s | ConvertTo-Json -Depth 32 -Compress

Set-Prop (Get-OrAdd $s 'env') 'AI_CONFIG_DIR' $RepoDir
# Read-only commands from the template's allowlist; the user's own entries stay.
$permissions = Get-OrAdd $s 'permissions'
$allow = @(if ($permissions.PSObject.Properties['allow']) { $permissions.allow })
$templateAllow = @((Get-Content $SettingsSrc -Raw -Encoding UTF8 | ConvertFrom-Json).permissions.allow)
Set-Prop $permissions 'allow' @($allow + @($templateAllow | Where-Object { $allow -notcontains $_ }))
$plugins = Get-OrAdd $s 'enabledPlugins'
if (-not $plugins.PSObject.Properties['core@ai-config']) { Set-Prop $plugins 'core@ai-config' $true }
$markets = Get-OrAdd $s 'extraKnownMarketplaces'
if (-not $markets.PSObject.Properties['ai-config']) {
    Set-Prop $markets 'ai-config' ([pscustomobject]@{ source = [pscustomobject]@{ source = 'github'; repo = 'tellewsen/ai-config' } })
}
Set-Prop $markets.'ai-config' 'autoUpdate' $true

if (($s | ConvertTo-Json -Depth 32 -Compress) -eq $before) {
    Write-Info "settings.json already up to date"
} else {
    if (-not $fresh) { Set-Content -Path "$SettingsTarget.bak.$Timestamp" -Value $raw -NoNewline -Encoding UTF8 }
    # UTF-8 without BOM: Windows PowerShell's -Encoding UTF8 writes a BOM.
    [IO.File]::WriteAllText($SettingsTarget, ($s | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
    if ($fresh) { Write-Ok "Set AI_CONFIG_DIR in settings.json" }
    else { Write-Ok "Updated settings.json (backup: settings.json.bak.$Timestamp)" }
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
Write-Host "  Linked:    ~\.claude\CLAUDE.md, ~\.claude\AGENTS.md (+ Copilot CLI / Codex when installed)"
Write-Host "  Plugin:    core@ai-config (agents core:<name>, skills /core:<name>), auto-updates"
Write-Host "  Memory:    $MemoryFile"
