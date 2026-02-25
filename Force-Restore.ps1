$stateRepo = 'C:\state-repo'
Write-Host "Forcing Manual Restore..." -ForegroundColor Yellow
Set-Location $stateRepo
Write-Host "Pulling latest settings from GitHub..."
# CRITICAL: Reset any local changes and pull the official state from the repo
git reset --hard HEAD
git pull origin main --rebase

$User = New-Object System.Security.Principal.NTAccount("cardersparadox")
$sid = $User.Translate([System.Security.Principal.SecurityIdentifier]).value
Write-Host "Applying settings for SID: $sid..."
if (Test-Path "$stateRepo\Registry") {
    Get-ChildItem -Path "$stateRepo\Registry" -Filter "*.reg" | ForEach-Object { 
        $content = Get-Content $_.FullName
        $content = $content -replace "HKEY_CURRENT_USER", "HKEY_USERS\$sid"
        $content | Out-File -FilePath $_.FullName -Encoding Unicode
        Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($_.FullName)`"" -Wait
    }
    Write-Host "Restarting Explorer to apply changes..."
    Stop-Process -Name explorer -Force
    Write-Host "Restore Complete! You can close this window." -ForegroundColor Cyan
} else {
    Write-Host "No registry backup found in repository!" -ForegroundColor Red
}
Start-Sleep -Seconds 5
