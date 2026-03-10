param(
  [int]$Limit = 50
)

$ErrorActionPreference = 'Stop'

$raw = git log --date=iso-strict --pretty=format:"commit:%H|%h|%an|%ad|%s" --numstat --name-status -n $Limit
$lines = @()
if ($raw) {
  if ($raw -is [System.Array]) {
    $lines = $raw
  } else {
    $lines = $raw -split "`n"
  }
}

$commits = @()
$curr = $null

function Finalize-Commit {
  param([hashtable]$c)
  if (-not $c) { return }

  if (-not $c.files) { $c.files = @() }
  if (-not $c.statusByPath) { $c.statusByPath = @{} }

  foreach ($f in $c.files) {
    if ($null -ne $f.path -and (-not $f.status) -and $c.statusByPath.ContainsKey($f.path)) {
      $f.status = $c.statusByPath[$f.path]
    }
  }

  if ($c.files.Count -eq 0 -and $c.statusByPath.Count -gt 0) {
    foreach ($k in $c.statusByPath.Keys) {
      $c.files += [pscustomobject]@{
        path = $k
        insertions = $null
        deletions = $null
        status = $c.statusByPath[$k]
      }
    }
  }

  $paths = @()
  foreach ($f in $c.files) {
    if ($null -ne $f.path) { $paths += $f.path }
  }
  $c.filesChanged = ($paths | Select-Object -Unique).Count
  $c.stats = [ordered]@{
    files = $c.filesChanged
    insertions = $c.insertions
    deletions = $c.deletions
  }

  $c.Remove('statusByPath')
  $script:commits += $c
}

foreach ($line in $lines) {
  if (-not $line) { continue }
  if ($line -like 'commit:*') {
    Finalize-Commit -c $curr

    $parts = $line.Substring(7).Split('|', 5)
    $curr = [ordered]@{
      hash = $parts[0]
      shortHash = $parts[1]
      author = $parts[2]
      date = $parts[3]
      message = $parts[4]
      insertions = 0
      deletions = 0
      files = @()
      statusByPath = @{}
    }
    continue
  }

  if (-not $curr) { continue }

  if ($line -match '^\d+\s+\d+\s+') {
    $parts = $line -split "\s+", 3
    $ins = [int]$parts[0]
    $del = [int]$parts[1]
    $path = $parts[2]
    $curr.insertions += $ins
    $curr.deletions += $del
    $curr.files += [pscustomobject]@{
      path = $path
      insertions = $ins
      deletions = $del
      status = $null
    }
    continue
  }

  if ($line -match '^-\s+-\s+') {
    $parts = $line -split "\s+", 3
    $path = $parts[2]
    $curr.files += [pscustomobject]@{
      path = $path
      insertions = $null
      deletions = $null
      status = $null
    }
    continue
  }

  if ($line -match '^[A-Z]\t') {
    $statusParts = $line -split "\t", 2
    $status = $statusParts[0]
    $path = $statusParts[1]
    $curr.statusByPath[$path] = $status
    continue
  }
}

Finalize-Commit -c $curr

$data = [ordered]@{
  generatedAt = (Get-Date).ToString('s')
  commits = $commits
}

$json = $data | ConvertTo-Json -Depth 6
Set-Content -Path "history.json" -Value $json -Encoding ASCII
