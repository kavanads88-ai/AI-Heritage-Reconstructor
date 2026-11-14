# Starts the backend. Run from the repository root in PowerShell:  .\scripts\run_backend.ps1
Set-Location "$PSScriptRoot\..\backend"
if (-not (Test-Path ".\venv\Scripts\Activate.ps1")) {
    Write-Host "Creating virtual environment..."
    python -m venv venv
    .\venv\Scripts\Activate.ps1
    python -m pip install --upgrade pip
    pip install -r requirements.txt
} else {
    .\venv\Scripts\Activate.ps1
}
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
