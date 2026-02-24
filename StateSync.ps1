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

# Calculate the precise RDP SID to forcefully bypass the runneradmin execution context
$User = New-Object System.Security.Principal.NTAccount("cardersparadox")
$sid = $User.Translate([System.Security.Principal.SecurityIdentifier]).value

Write-Log "========================================"
Write-Log "Sync Agent Initialized. Mapped Target RDP SID: $sid"
Write-Log "========================================"

if (-not (Test-Path $restoredFlag)) {
    if (Test-Path "$stateRepo\Registry") {
        Write-Log "Found existing Registry backups. Starting precise UI configuration import..."
        Get-ChildItem -Path "$stateRepo\Registry" -Filter "*.reg" | ForEach-Object { 
            # Dynamically inject the correct SID into the text file so the import succeeds cross-profile
            $regContent = Get-Content $_.FullName
            $regContent = $regContent -replace "HKEY_CURRENT_USER", "HKEY_USERS\$sid"
            $regContent | Out-File -FilePath $_.FullName -Encoding Unicode
            
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
    Set-Location $stateRepo
    git config user.name "RDP Sync Agent"
    git config user.email "agent@rdp.local"
    git config --global core.safecrlf false
    
    # Pulled to the top to prevent dirty rebase warnings
    Write-Log "Pulling latest remote changes (rebase)..."
    $pullOutput = git pull origin main --rebase 2>&1
    Write-Log "Git Pull Output: $pullOutput"
    
    New-Item -Path "$stateRepo\Registry" -ItemType Directory -Force | Out-Null
    
    # Export strictly from the calculated mathematical SID to prevent empty runneradmin backups
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "$stateRepo\Registry\Personalize.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "$stateRepo\Registry\ExplorerAdvanced.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "$stateRepo\Registry\StuckRects3.reg" /y
    reg export "HKEY_USERS\$sid\Software\Microsoft\Windows\DWM" "$stateRepo\Registry\DWM.reg" /y
    reg export "HKEY_USERS\$sid\Control Panel\Desktop" "$stateRepo\Registry\Desktop.reg" /y
    Write-Log "Native cross-profile registry keys exported successfully."
    
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
