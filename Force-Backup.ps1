Write-Host "Forcing Manual Backup..." -ForegroundColor Green
Set-Location "C:\state-repo"
git add .
git commit -m "Manual Backup $(Get-Date -Format 'HH:mm:ss')"
git push origin main
Write-Host "Backup Sent! You can close this window." -ForegroundColor Cyan
Pause
