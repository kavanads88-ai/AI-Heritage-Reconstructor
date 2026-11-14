# Copies historical_data/monuments.json into the Flutter app's bundled assets.
# Run from the repository root in PowerShell:  .\scripts\sync_data.ps1
Copy-Item -Path "historical_data\monuments.json" -Destination "mobile_app\assets\data\monuments.json" -Force
Write-Host "Synced monuments.json into mobile_app/assets/data/"
