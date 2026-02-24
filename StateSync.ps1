$ErrorActionPreference = 'SilentlyContinue'
$stateRepo = 'C:\state-repo'
$logDir = "$stateRepo\Logs"
$logFile = "$logDir\SyncAgent.log"
$restoredFlag = "$env:TEMP\registry_restored.flag"

if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] $Message"
    Out-File -FilePath $logFile -InputObject $logLine -Append -Encoding UTF8
}

Write-Log "========================================"
Write-Log "Sync Agent Initialized with Highest Privileges. User: $env:USERNAME"
Write-Log "========================================"

if (-not (Test-Path $restoredFlag)) {
    if (Test-Path "$stateRepo\Registry") {
        Write-Log "Found existing Registry backups. Starting UI configuration import..."
        Get-ChildItem -Path "$stateRepo\Registry" -Filter "*.reg" | ForEach-Object { 
            $importResult = Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($_.FullName)`"" -Wait -PassThru
            Write-Log "Imported $($_.Name) with exit code: $($importResult.ExitCode)"
        }
        Write-Log "Restarting Windows Explorer to instantly apply visual changes."
        Stop-Process -Name explorer -Force
    } else {
        Write-Log "No existing Registry folder found. Proceeding with fresh configuration."
    }
    New-Item -Path $restoredFlag -ItemType File | Out-Null
    Write-Log "Restoration flag created. Skipping future imports for this session."
}

while ($true) {
    Write-Log "Initiating routine 1-minute sync and export cycle..."
    
    New-Item -Path "$stateRepo\Registry" -ItemType Directory -Force | Out-Null
    
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "$stateRepo\Registry\Personalize.reg" /y
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "$stateRepo\Registry\ExplorerAdvanced.reg" /y
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "$stateRepo\Registry\StuckRects3.reg" /y
    reg export "HKCU\Software\Microsoft\Windows\DWM" "$stateRepo\Registry\DWM.reg" /y
    reg export "HKCU\Control Panel\Desktop" "$stateRepo\Registry\Desktop.reg" /y
    Write-Log "Native registry keys exported successfully."
    
    Set-Location $stateRepo
    git config user.name "RDP Sync Agent"
    git config user.email "agent@rdp.local"
    git config --global core.safecrlf false
    
    Write-Log "Pulling latest remote changes (rebase)..."
    $pullOutput = git pull origin main --rebase 2>&1
    Write-Log "Git Pull Output: $pullOutput"
    
    $status = git status --porcelain
    if ($status) {
        Write-Log "Changes detected. Committing..."
        git add . 
        $commitMsg = "Auto-save Windows UI & Telemetry $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 
        git commit -m "$commitMsg" 2>&1 | Out-Null
        
        Write-Log "Pushing to GitHub..."
        $pushOutput = git push origin main 2>&1
        Write-Log "Git Push Output: $pushOutput"
    }
    
    Write-Log "Cycle complete. Sleeping for 1 minute before next sync..."
    Start-Sleep -Seconds 60
}
