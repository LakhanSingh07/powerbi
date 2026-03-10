param(
  [Parameter(Mandatory=$true)]
  [string]$Message
)

$ErrorActionPreference = 'Stop'

git status -sb

git add -A

# If nothing to commit, exit gracefully
$diff = git diff --cached --name-only
if (-not $diff) {
  Write-Host "Nothing to commit."
  exit 0
}

git commit -m $Message

git push
