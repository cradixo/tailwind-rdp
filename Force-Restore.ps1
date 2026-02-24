Write-Host "Forcing Manual Restore..." -ForegroundColor Yellow
Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
Start-Process -FilePath "powershell.exe" -ArgumentList "-File C:\state-repo\StateSync.ps1" -Verb RunAs
Write-Host "Restore Triggered." -ForegroundColor Cyan
Pause
