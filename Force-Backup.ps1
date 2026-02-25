# --- SELF-ELEVATION GUARD: Check for Admin rights and re-launch if necessary ---
$currentUser = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -File `"$PSCommandPath`"";
    exit;
}
$stateRepo = 'C:\state-repo'
Write-Host "Forcing Manual Backup..." -ForegroundColor Green
Set-Location $stateRepo
$User = New-Object System.Security.Principal.NTAccount("cardersparadox")
$sid = $User.Translate([System.Security.Principal.SecurityIdentifier]).value
Write-Host "Exporting current settings for SID: $sid..."
reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "$stateRepo\Registry\Personalize.reg" /y
reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "$stateRepo\Registry\ExplorerAdvanced.reg" /y
reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "$stateRepo\Registry\StuckRects3.reg" /y
reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\DWM" "$stateRepo\Registry\DWM.reg" /y
reg export "HKEY_USERS\$sid\Control Panel\Desktop" "$stateRepo\Registry\Desktop.reg" /y
Write-Host "Committing and Pushing to GitHub..."
git add .
git commit -m "Manual Backup $(Get-Date -Format 'HH:mm:ss')"
git push origin main
Write-Host "Backup Sent! You can close this window." -ForegroundColor Cyan
Start-Sleep -Seconds 5
