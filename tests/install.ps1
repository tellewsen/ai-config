# Tests install.ps1 against throwaway profiles: a fresh machine, and one set up before
# the core plugin existed. A stub claude.cmd on PATH records calls, so nothing real is
# installed. Windows only (install.ps1 builds Windows paths); runs on PowerShell 5.1 and 7.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\install.ps1
#   pwsh -NoProfile -File tests\install.ps1

$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Work = Join-Path ([IO.Path]::GetTempPath()) ("ai-config-install-" + [guid]::NewGuid())
$script:Pass = 0; $script:Fail = 0

function Check($desc, [scriptblock]$test) {
    $ok = $false
    try { $ok = [bool](& $test) } catch { }
    if ($ok) { $script:Pass++ } else { $script:Fail++; Write-Host "FAIL: $desc" }
}

# Each case gets its own copy of the repo, since migration moves files out of it.
function New-Case($name) {
    $d = Join-Path $Work $name
    $case = @{
        Repo   = Join-Path $d 'repo'
        Home   = Join-Path $d 'home'
        Claude = Join-Path $d 'home\.claude'
        Bin    = Join-Path $d 'bin'
    }
    New-Item -ItemType Directory -Force -Path $case.Claude, $case.Bin | Out-Null
    Copy-Item $Repo $case.Repo -Recurse
    Remove-Item (Join-Path $case.Repo '.git') -Recurse -Force -ErrorAction SilentlyContinue
    Set-Content -Path (Join-Path $case.Bin 'claude.cmd') -Encoding ASCII -Value "@echo %* >> `"$($case.Home)\claude-calls`""
    return $case
}

function Invoke-Install($case) {
    $savedProfile = $env:USERPROFILE; $savedPath = $env:PATH
    # PowerShell 5.1 turns a child's stderr into errors; the exit code is what matters here.
    $ErrorActionPreference = 'Continue'
    # A UNC working directory (running from WSL) makes cmd.exe, and so the stub, refuse to run.
    Push-Location $case.Home
    try {
        $env:USERPROFILE = $case.Home
        $env:PATH = "$($case.Bin);$env:PATH"
        $exe = (Get-Process -Id $PID).Path
        $out = Join-Path $case.Home 'out'
        & $exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $case.Repo 'install.ps1') *> $out
        if ($LASTEXITCODE -ne 0) { Get-Content $out | Write-Host }
        return $LASTEXITCODE -eq 0
    } finally {
        $env:USERPROFILE = $savedProfile; $env:PATH = $savedPath
        Pop-Location
    }
}

try {
    # -- Fresh machine ---------------------------------------------------------
    $c = New-Case 'fresh'
    Check 'fresh: install succeeds' { Invoke-Install $c }
    # Symlinks need Developer Mode or admin; CI runners have admin, and elsewhere a copy is the fallback.
    if ($env:CI) {
        Check 'fresh: CLAUDE.md is a symlink' { (Get-Item (Join-Path $c.Claude 'CLAUDE.md')).LinkType -eq 'SymbolicLink' }
    } else {
        Check 'fresh: CLAUDE.md installed' { Test-Path (Join-Path $c.Claude 'CLAUDE.md') }
    }
    Check 'fresh: settings copied from template' {
        $s = Get-Content (Join-Path $c.Claude 'settings.json') -Raw | ConvertFrom-Json
        $s.enabledPlugins.'core@ai-config' -eq $true -and $s.extraKnownMarketplaces.'ai-config'.autoUpdate -eq $true
    }
    Check 'fresh: AGENTS.md installed' { (Get-Content (Join-Path $c.Claude 'AGENTS.md') -Raw) -match 'Global Agent Instructions' }
    Check 'fresh: AI_CONFIG_DIR points at the repo' {
        (Get-Content (Join-Path $c.Claude 'settings.json') -Raw | ConvertFrom-Json).env.AI_CONFIG_DIR -eq $c.Repo
    }
    Check 'fresh: no backup of a settings file we just created' { -not (Test-Path (Join-Path $c.Claude 'settings.json.bak.*')) }
    Check 'fresh: plugin installed' { (Get-Content (Join-Path $c.Home 'claude-calls')) -match 'plugin install core@ai-config' }

    # -- Machine set up before the plugin --------------------------------------
    $c = New-Case 'legacy'
    $agents = Join-Path $c.Claude 'agents'
    $memory = Join-Path $c.Claude 'agent-memory'
    New-Item -ItemType Directory -Force -Path $agents, (Join-Path $memory 'debugger') | Out-Null
    foreach ($n in 'debugger', 'code-reviewer', 'security-auditor', 'my-own') { Set-Content (Join-Path $agents "$n.md") 'old' }
    Set-Content (Join-Path $memory 'debugger\MEMORY.md') '# debugger notes'
    # Written as UTF-8 without BOM, like Claude Code does, with a non-ASCII character
    # that a wrong read encoding would garble.
    [IO.File]::WriteAllText((Join-Path $c.Claude 'settings.json'), '{"theme": "dark", "permissions": {"allow": ["Bash(make lint)"]}, "note": "caf' + [char]0xE9 + '", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "[ -n \"$AI_CONFIG_DIR\" ] && echo sync"}, {"type": "command", "command": "notify-send done"}]}], "SessionStart": [{"hooks": [{"type": "command", "command": "git -C \"$AI_CONFIG_DIR\" pull"}]}]}}', (New-Object Text.UTF8Encoding $false))
    $copilot = Join-Path $c.Home '.copilot'
    New-Item -ItemType Directory -Force -Path $copilot | Out-Null
    Set-Content (Join-Path $copilot 'copilot-instructions.md') 'old copilot rules'

    Check 'legacy: install succeeds' { Invoke-Install $c }
    Check 'legacy: old agent copy removed' { -not (Test-Path (Join-Path $agents 'debugger.md')) }
    Check 'legacy: retired agents removed' {
        -not (Test-Path (Join-Path $agents 'code-reviewer.md')) -and -not (Test-Path (Join-Path $agents 'security-auditor.md'))
    }
    Check "legacy: user's own agent kept" { Test-Path (Join-Path $agents 'my-own.md') }
    Check 'legacy: memory moved to core-<name>' { (Get-Content (Join-Path $memory 'core-debugger\MEMORY.md')) -match 'debugger notes' }
    $settingsPath = Join-Path $c.Claude 'settings.json'
    Check 'legacy: unrelated settings kept' {
        $s = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
        $s.theme -eq 'dark' -and $s.note -eq ('caf' + [char]0xE9)
    }
    Check 'legacy: settings enable core with autoUpdate and AI_CONFIG_DIR' {
        $s = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
        $s.enabledPlugins.'core@ai-config' -eq $true -and $s.extraKnownMarketplaces.'ai-config'.autoUpdate -eq $true -and $s.env.AI_CONFIG_DIR -eq $c.Repo
    }
    Check 'legacy: allowlist merged, own entries kept' {
        $allow = @(([IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json).permissions.allow)
        $allow[0] -eq 'Bash(make lint)' -and $allow -contains 'Bash(ssh-add -l)' -and $allow.Count -eq 6
    }
    Check 'legacy: old sync hooks removed, own hook kept' {
        $s = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
        $s.hooks.Stop[0].hooks.Count -eq 1 -and $s.hooks.Stop[0].hooks[0].command -eq 'notify-send done' -and -not $s.hooks.PSObject.Properties['SessionStart']
    }
    Check 'legacy: settings written without BOM' { [IO.File]::ReadAllBytes($settingsPath)[0] -eq [byte][char]'{' }
    Check 'legacy: settings backup written' { @(Get-ChildItem "$settingsPath.bak.*").Count -eq 1 }
    Check 'legacy: Copilot CLI instructions replaced by AGENTS.md' {
        (Get-Content (Join-Path $copilot 'copilot-instructions.md') -Raw) -match 'Global Agent Instructions'
    }
    Check 'legacy: old Copilot instructions backed up' { @(Get-ChildItem (Join-Path $copilot 'copilot-instructions.md.bak.*')).Count -eq 1 }
    $settingsBefore = [IO.File]::ReadAllText($settingsPath)

    Check 'rerun: install succeeds' { Invoke-Install $c }
    Check 'rerun: settings unchanged' { [IO.File]::ReadAllText($settingsPath) -eq $settingsBefore }
    Check 'rerun: no new settings backup' { @(Get-ChildItem "$settingsPath.bak.*").Count -eq 1 }
    Check 'rerun: memory still in place' { Test-Path (Join-Path $memory 'core-debugger\MEMORY.md') }
} finally {
    Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "$script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
