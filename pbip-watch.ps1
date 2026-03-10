param(
  [int]$IntervalSeconds = 10,
  [int]$CommitIntervalMinutes = 5,
  [int]$HistoryIntervalSeconds = 60,
  [int]$HistoryLimit = 50,
  [switch]$CommitOnChange
)

$ErrorActionPreference = 'Stop'

function Write-StatusFile {
  param(
    [string[]]$StatusLines,
    [string]$DiffStat,
    [datetime]$LastCommit,
    [Nullable[datetime]]$LastChange,
    [bool]$Pending
  )

  $data = [ordered]@{
    timestamp = (Get-Date).ToString('s')
    pending = $Pending
    lastChange = if ($LastChange.HasValue) { $LastChange.Value.ToString('s') } else { $null }
    lastCommit = $LastCommit.ToString('s')
    status = $StatusLines
    diffStat = $DiffStat
  }

  $json = $data | ConvertTo-Json -Depth 3
  Set-Content -Path "status.json" -Value $json -Encoding ASCII

  $summary = @(
    "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Pending: $Pending",
    "Last change: " + $(if ($LastChange.HasValue) { $LastChange.Value.ToString('yyyy-MM-dd HH:mm:ss') } else { 'n/a' }),
    "Last commit: $($LastCommit.ToString('yyyy-MM-dd HH:mm:ss'))",
    "",
    "Git status:",
    ($StatusLines | ForEach-Object { "  $_" }),
    "",
    "Diff stat:",
    $DiffStat
  ) -join "`r`n"

  Set-Content -Path "change-summary.txt" -Value $summary -Encoding ASCII
}

$lastCommitTime = Get-Date
$lastChangeTime = $null
$pending = $false
$lastHistoryUpdate = Get-Date "2000-01-01"
$lastChangeSig = ""

function Update-History {
  param([int]$Limit)
  if (Test-Path -Path ".\\pbip-history.ps1") {
    try {
      & .\\pbip-history.ps1 -Limit $Limit | Out-Null
    } catch {
      # Keep watcher alive if history generation fails
    }
  }
}

while ($true) {
  $statusRaw = git status --porcelain
  $statusLines = @()
  if ($statusRaw) {
    $statusLines = $statusRaw -split "`n" | Where-Object { $_ -ne '' }
  }

  if ($statusLines.Count -gt 0) {
    $pending = $true
    $lastChangeTime = Get-Date
  }

  $diffStatWork = git diff --stat
  $changeSig = ($statusLines -join "`n") + "`n" + $diffStatWork

  Write-StatusFile -StatusLines $statusLines -DiffStat $diffStatWork -LastCommit $lastCommitTime -LastChange $lastChangeTime -Pending $pending

  if (((Get-Date) - $lastHistoryUpdate).TotalSeconds -ge $HistoryIntervalSeconds) {
    Update-History -Limit $HistoryLimit
    $lastHistoryUpdate = Get-Date
  }

  if ($CommitOnChange) {
    if ($pending -and $changeSig -ne $lastChangeSig) {
      git add -A
      $cached = git diff --cached --name-only
      if ($cached) {
        $msg = "Auto-commit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m $msg
        git push
        $lastCommitTime = Get-Date
        $pending = $false
        Update-History -Limit $HistoryLimit
        $lastHistoryUpdate = Get-Date
      } else {
        $pending = $false
        $lastCommitTime = Get-Date
      }
    }
  } else {
    $nextCommitTime = $lastCommitTime.AddMinutes($CommitIntervalMinutes)
    if ($pending -and (Get-Date) -ge $nextCommitTime) {
      git add -A
      $cached = git diff --cached --name-only
      if ($cached) {
        $msg = "Auto-commit: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        git commit -m $msg
        git push
        $lastCommitTime = Get-Date
        $pending = $false
        Update-History -Limit $HistoryLimit
        $lastHistoryUpdate = Get-Date
      } else {
        $pending = $false
        $lastCommitTime = Get-Date
      }
    }
  }

  $lastChangeSig = $changeSig

  Start-Sleep -Seconds $IntervalSeconds
}
