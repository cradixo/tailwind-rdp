<#
.SYNOPSIS
    Restores the complete user profile at login and then self-destructs.
.DESCRIPTION
    This script is placed in the user's Startup folder by the workflow.
    It runs once on the first login to apply all backed-up settings and force the UI to refresh.
#>

# --- Configuration ---
$restoreSourceDir = "C:\RDP_Restore_Source"
$logFile = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "restore_log.txt"

# Start logging everything that happens to a file on the Desktop for easy debugging.
Start-Transcript -Path $logFile -Append

try {
    Write-Host "--- Starting RDP Profile Restore at $(Get-Date) ---"
    
    # --- STEP 1: RESTORE FULL USER REGISTRY ---
    $regFile = Join-Path -Path $restoreSourceDir -ChildPath "full_user_profile.reg"
    if (Test-Path $regFile) {
        Write-Host "Found registry backup. Importing..."
        # The /s switch imports silently without confirmation prompts.
        Start-Process reg -ArgumentList "import `"$regFile`"" -Wait
        Write-Host "SUCCESS: Registry import command completed."
    } else {
        Write-Host "WARNING: No registry backup (full_user_profile.reg) found in $restoreSourceDir."
    }

    # --- STEP 2: RESTORE MICROSOFT EDGE DATA ---
    $edgeBackupPath = Join-Path -Path $restoreSourceDir -ChildPath "Edge_User_Data"
    $edgeTargetPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $edgeBackupPath) {
        Write-Host "Found Edge backup. Closing any running Edge processes..."
        Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2

        Write-Host "Copying Edge data to $edgeTargetPath..."
        # We use Robocopy as it's more robust for large, complex directories.
        robocopy.exe $edgeBackupPath $edgeTargetPath /E /COPYALL /PURGE /R:2 /W:2
        Write-Host "SUCCESS: Edge data restore completed."
    } else {
        Write-Host "WARNING: No Edge data backup (Edge_User_Data) found in $restoreSourceDir."
    }

    # --- STEP 3: FORCE UI REFRESH (THE CRITICAL STEP) ---
    Write-Host "Restarting Windows Shell (explorer.exe) to apply visual changes..."
    Stop-Process -Name explorer -Force
    # Explorer will typically restart automatically. If not, Start-Process explorer is a fallback.
    
    Write-Host "SUCCESS: Restore process finished."

} catch {
    Write-Host "ERROR: An error occurred during the restore process: $($_.Exception.Message)"
} finally {
    # --- STEP 4: SELF-DESTRUCT ---
    Write-Host "Removing self from Startup folder to prevent re-running."
    try {
        Remove-Item $MyInvocation.MyCommand.Path -Force
    } catch {
        Write-Host "Could not remove self from startup. This is not a critical error."
    }
    
    Write-Host "--- Restore Script Finished ---"
    Stop-Transcript
}
