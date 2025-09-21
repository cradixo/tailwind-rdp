<#
.SYNOPSIS
    Restores Windows theme settings and Microsoft Edge user data.
    This script is designed to run automatically on user login.
#>

# --- Paths ---
$userProfile = $env:USERPROFILE
$logFile = Join-Path -Path $userProfile -ChildPath "Desktop\restore_log.txt"
$restoreSourceDir = Join-Path -Path $userProfile -ChildPath "Documents\RDP_Backup_Source"
$edgeDataDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$regFileTheme = Join-Path -Path $restoreSourceDir -ChildPath "theme_settings.reg"
$edgeArchive = Join-Path -Path $restoreSourceDir -ChildPath "edge_data.zip"

# A flag file to ensure the script only runs once per session
$flagFile = Join-Path -Path $userProfile -ChildPath ".rdp_restored"

# --- Script Body ---
if (Test-Path $flagFile) {
    # If the flag file exists, do nothing.
    exit 0
}

Start-Transcript -Path $logFile

Write-Host "----------------------------------------------------"
Write-Host "Starting RDP Restore Process at $(Get-Date)"
Write-Host "----------------------------------------------------"

# 1. Restore Theme Settings
Write-Host "[STEP 1/2] Restoring theme settings..."
if (Test-Path $regFileTheme) {
    try {
        reg import $regFileTheme
        Write-Host "  - SUCCESS: Imported theme settings from registry file."
    } catch {
        Write-Error "  - FAILED: Could not import registry settings. Error: $_"
    }
} else {
    Write-Host "  - INFO: No theme backup file found. Skipping."
}

# 2. Restore Microsoft Edge Data
Write-Host "[STEP 2/2] Restoring Microsoft Edge data..."
if (Test-Path $edgeArchive) {
    try {
        # Ensure Edge is not running
        Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2

        if (Test-Path $edgeDataDir) {
            Remove-Item $edgeDataDir -Recurse -Force
            Write-Host "  - Removed old Edge data directory."
        }
        
        Expand-Archive -Path $edgeArchive -DestinationPath $edgeDataDir
        Write-Host "  - SUCCESS: Expanded Edge data backup."
    } catch {
        Write-Error "  - FAILED: Could not restore Edge data. Error: $_"
    }
} else {
    Write-Host "  - INFO: No Edge data backup file found. Skipping."
}

Write-Host "----------------------------------------------------"
Write-Host "Restore complete. This script will not run again this session."
Write-Host "----------------------------------------------------"

# Create the flag file to prevent the script from running again
New-Item -Path $flagFile -ItemType File | Out-Null

Stop-Transcript
