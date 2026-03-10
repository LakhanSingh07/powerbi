$ErrorActionPreference = 'Stop'

$port = 8000

try {
  while ($true) {
    # Start a simple HTTP server in the repo root
    python -m http.server $port | Out-Null
    Start-Sleep -Seconds 2
  }
} catch {
  Write-Host "HTTP server exited." 
}
