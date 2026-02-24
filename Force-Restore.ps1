Write-Host "Forcing Manual Restore..." -ForegroundColor Yellow
Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
$restoredFlag = "$env:TEMP\registry_restored.flag"
if(Test-Path $restoredFlag) { Remove-Item $restoredFlag -Force }
Start-Process -FilePath "powershell.exe" -ArgumentList "-File C:\state-repo\StateSync.ps1" -Verb RunAs
Write-Host "Restore Triggered." -ForegroundColor Cyan
Pause
