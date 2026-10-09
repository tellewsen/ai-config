# SessionStart hook, PowerShell twin of handoff-check.sh for Windows without Git Bash.
# Keep the two in step (tests/run.sh checks both). Works in Windows PowerShell 5.1 and pwsh 7.

$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$hook = $null
if ($raw) { $hook = $raw | ConvertFrom-Json }
$cwd = if ($hook -and $hook.cwd) { [string]$hook.cwd } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$session = if ($hook) { [string]$hook.session_id } else { '' }
$source = if ($hook) { [string]$hook.source } else { '' }

$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$dir = Join-Path $configDir 'handoffs'
if (-not (Test-Path -LiteralPath $dir -PathType Container)) { exit 0 }

function Retire($path) {
  $resumed = Join-Path (Split-Path -Parent $path) 'resumed'
  New-Item -ItemType Directory -Force -Path $resumed | Out-Null
  $dest = Join-Path $resumed (Split-Path -Leaf $path)
  Move-Item -LiteralPath $path -Destination $dest -Force
  (Get-Item -LiteralPath $dest).LastWriteTime = Get-Date
}

# Housekeeping: a note nobody resumed in 30 days is stale, so retire it to resumed/;
# resumed notes are kept 30 more days in case one is needed again, then deleted.
$cutoff = (Get-Date).AddDays(-30)
$topNotes = @(Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object {
  Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.md'
})
$topNotes | Where-Object { $_.LastWriteTime -lt $cutoff } | ForEach-Object { Retire $_.FullName }
Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object {
  $r = Join-Path $_.FullName 'resumed'
  if (Test-Path -LiteralPath $r) {
    Get-ChildItem -LiteralPath $r -File -Filter '*.md' | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Force
  }
}
Get-ChildItem -LiteralPath $dir -Directory -Recurse | Sort-Object { $_.FullName.Length } -Descending |
  Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } | Remove-Item -Force

# Notes whose Dir line (within the first 10 lines) is exactly this directory, newest first,
# one per session.
$notes = @()
Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object {
  Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.md' | ForEach-Object {
    $lines = @(Get-Content -LiteralPath $_.FullName -TotalCount 10)
    $sid = ''; $hit = $false
    foreach ($l in $lines) {
      $l = $l.TrimEnd("`r")
      if ($l.StartsWith('Session: ')) { $sid = $l.Substring(9) }
      if ($l -ceq "Dir: $cwd") { $hit = $true }
    }
    if ($hit) { $notes += [pscustomobject]@{ Sid = $sid; Path = $_.FullName; Name = $_.Name } }
  }
}
$seen = @{}
$notes = @($notes | Sort-Object Name -Descending | Where-Object {
  if (-not $_.Sid) { $true } elseif ($seen.ContainsKey($_.Sid)) { $false } else { $seen[$_.Sid] = 1; $true }
})
if ($notes.Count -eq 0) { exit 0 }

# Resuming the paused session itself: the conversation already holds everything, so
# retire its note quietly and don't distract with notes from parallel sessions.
if ($source -eq 'resume' -and $session) {
  $own = @($notes | Where-Object { $_.Sid -eq $session })
  if ($own.Count -eq 0) { exit 0 }
  $own | ForEach-Object { Retire $_.Path }
  Write-Output "This session was paused with /pause earlier; its handoff note has been retired to resumed/. The conversation above already has the context, so pick up from where it stopped."
  exit 0
}

Write-Output 'Unresumed /pause handoff notes exist for this directory (newest first):'
$notes | Select-Object -First 5 | ForEach-Object {
  if ($_.Sid) { Write-Output "- $($_.Path) (full conversation: claude --resume $($_.Sid))" } else { Write-Output "- $($_.Path)" }
}
Write-Output ''
Write-Output "In your first reply, mention them in one line and offer to resume, either by reading the note here or by resuming the original session with the command shown. Notes from parallel sessions in the same directory can appear here, so let the user pick if there are several. When you resume from a note, read it fully, then move it into a 'resumed' subfolder next to it so it is not offered again."
exit 0
