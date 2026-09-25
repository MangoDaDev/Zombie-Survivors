$ErrorActionPreference = "Stop"

$PinevexRoot = "C:\Users\Ryan Bridges\OneDrive\Documents\pinevex-renderer"
$Python = Join-Path $PinevexRoot ".venv\Scripts\python.exe"
$HealthUrl = "http://127.0.0.1:8000/health"

# If Pinevex is already running, do nothing.
try {
    $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2

    if ($response.status -eq "ok") {
        Write-Host "Pinevex is already running."
        exit 0
    }
}
catch {
    # Not running yet. Continue and start it.
}

if (-not (Test-Path $Python)) {
    Write-Error "Pinevex Python environment not found at: $Python"
    exit 1
}

Write-Host "Starting Pinevex..."

Start-Process `
    -FilePath $Python `
    -ArgumentList "-m", "uvicorn", "api.index:app", "--host", "127.0.0.1", "--port", "8000" `
    -WorkingDirectory $PinevexRoot `
    -WindowStyle Hidden

# Wait for the server to become ready.
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500

    try {
        $response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2

        if ($response.status -eq "ok") {
            Write-Host "Pinevex is running at http://127.0.0.1:8000"
            exit 0
        }
    }
    catch {
        # Keep waiting.
    }
}

Write-Error "Pinevex did not start successfully."
exit 1