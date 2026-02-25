if ($env:USERNAME -ne "cardersparadox") { exit }
$ErrorActionPreference = 'SilentlyContinue'
$stateRepo = 'C:\state-repo'
$logDir = "$stateRepo\Logs"
$logFile = "$logDir\SyncAgent.log"
$restoredFlag = "$env:TEMP\registry_restored.flag"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
function Write-Log { param([string]$Message); $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logLine = "[$timestamp] $Message"; Out-File -FilePath $logFile -InputObject $logLine -Append -Encoding UTF8 }
while (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 1 }
Copy-Item "$stateRepo\Force-Backup.ps1" "$env:USERPROFILE\Desktop\Force-Backup.ps1" -Force
Copy-Item "$stateRepo\Force-Restore.ps1" "$env:USERPROFILE\Desktop\Force-Restore.ps1" -Force
$User = New-Object System.Security.Principal.NTAccount("cardersparadox")
$sid = $User.Translate([System.Security.Principal.SecurityIdentifier]).value
Write-Log "=== AGENT STARTED: $sid ==="
if (-not (Test-Path $restoredFlag)) {
    if (Test-Path "$stateRepo\Registry") {
        Write-Log "Found backup. Restoring..."
        Get-ChildItem -Path "$stateRepo\Registry" -Filter "*.reg" | ForEach-Object { 
            $content = Get-Content $_.FullName
            $content = $content -replace "HKEY_CURRENT_USER", "HKEY_USERS\$sid"
            $content | Out-File -FilePath $_.FullName -Encoding Unicode
            Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($_.FullName)`"" -Wait
        }
        taskkill /F /IM explorer.exe | Out-Null
        Write-Log "Restoration Complete."
    }
    New-Item -Path $restoredFlag -ItemType File | Out-Null
}
while ($true) {
    Set-Location $stateRepo
    git config user.name "RDP Sync Agent"
    git config user.email "agent@rdp.local"
    git pull origin main --rebase 2>&1 | Out-Null
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "$stateRepo\Registry\Personalize.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "$stateRepo\Registry\ExplorerAdvanced.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "$stateRepo\Registry\StuckRects3.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\DWM" "$stateRepo\Registry\DWM.reg" /y
    reg export "HKEY_USERS\$sid\Control Panel\Desktop" "$stateRepo\Registry\Desktop.reg" /y
    git add Registry/*.reg
    $regStatus = git status --porcelain Registry/
    if ($regStatus) {
        Write-Log "SETTINGS CHANGED. Committing..."
        git add .
        $msg = "Auto-save Settings $(Get-Date -Format 'HH:mm:ss')"
        git commit -m "$msg" 2>&1 | Out-Null
        git push origin main 2>&1
        Write-Log "Push Complete."
    } else { Write-Log "No setting changes detected." }
    Start-Sleep -Seconds 300
}
