# PowerShell twin of ai-config.sh for Windows without Git Bash. Keep the two in step
# (tests/run.sh checks both). Works in Windows PowerShell 5.1 and pwsh 7.

$ErrorActionPreference = 'Continue'
$null = [Console]::In.ReadToEnd()
$dir = $env:AI_CONFIG_DIR
if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { exit 0 }
function Say($text) { @{ systemMessage = $text } | ConvertTo-Json -Compress }

switch ($args[0]) {
  'pull' {
    # Fail instead of prompting: nobody can type a passphrase or password into a hook.
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GIT_SSH_COMMAND = "$(if ($env:GIT_SSH_COMMAND) { $env:GIT_SSH_COMMAND } else { 'ssh' }) -o BatchMode=yes"
    $out = git -C $dir pull --ff-only --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
      $reason = @($out | ForEach-Object { "$_".Trim() } | Where-Object { $_ })[0]
      if (-not $reason) { $reason = 'git pull failed' }
      if ($reason.Length -gt 200) { $reason = $reason.Substring(0, 200) }
      Say "ai-config was not updated ($reason). Pull it by hand: git -C `"`$AI_CONFIG_DIR`" pull"
    }
  }
  'nag' {
    $status = (git -C $dir status --porcelain 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0) { exit 0 }
    $seen = Join-Path (git -C $dir rev-parse --absolute-git-dir) 'sync-nag'
    if (-not $status) { Remove-Item -LiteralPath $seen -ErrorAction SilentlyContinue; exit 0 }
    $last = if (Test-Path -LiteralPath $seen) { [IO.File]::ReadAllText($seen) } else { '' }
    if ($status -eq $last) { exit 0 }
    [IO.File]::WriteAllText($seen, $status)
    Say "ai-config has uncommitted changes - run /core:sync to save your learnings."
  }
}
exit 0
