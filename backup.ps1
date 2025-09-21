<#
.SYNOPSIS
    Backs up the user's RDP profile (Theme and Edge data) to a GitHub Release.
    This script is intended to be run manually from the RDP Desktop.
.DESCRIPTION
    The script gathers necessary files, creates a single versioned ZIP archive,
    and uses the GitHub CLI (gh) to upload the archive as a release asset,
    overwriting any previous backup.
#>

# --- Configuration ---
$githubUsername = "cradixo"
$repositoryName = "tailwind-rdp"
$releaseTag = "latest-rdp-profile" # The static tag for our profile release

# This placeholder is replaced by the GitHub Actions workflow with your secret PAT.
$pat = "GIT_PAT_PLACEHOLDER"

# --- Function for Detailed Logging ---
function Log-Message {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# --- Script Body ---
# Create a temporary staging area for the backup files
$stagingDir = New-Item -Path $env:TEMP -Name "RdpBackup_$(Get-Random)" -ItemType Directory
Log-Message "Created temporary staging directory at $($stagingDir.FullName)"

try {
    # --- STEP 1: VERIFY REQUIREMENTS ---
    Log-Message "Verifying requirements..."
    if ($pat -eq "GIT_PAT_PLACEHOLDER" -or [string]::IsNullOrWhiteSpace($pat)) {
        throw "CRITICAL: GIT_PAT placeholder was not replaced. This is a workflow error."
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "CRITICAL: GitHub CLI ('gh') is not installed or not in PATH. This should be pre-installed on runners."
    }
    Log-Message "GitHub CLI and authentication token are present." -Level "SUCCESS"

    # --- STEP 2: CLOSE MICROSOFT EDGE ---
    Log-Message "Ensuring Microsoft Edge is closed to prevent data corruption..."
    Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -Verbose
    Start-Sleep -Seconds 3 # Allow time for file handles to be released

    # --- STEP 3: GATHER THEME SETTINGS ---
    Log-Message "Exporting theme settings from registry..."
    $regFile = Join-Path -Path $stagingDir.FullName -ChildPath "theme_settings.reg"
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes" $regFile /y
    if (Test-Path $regFile) {
        Log-Message "Successfully exported theme settings." -Level "SUCCESS"
    } else {
        throw "Failed to export theme registry settings."
    }

    # --- STEP 4: GATHER MICROSOFT EDGE DATA ---
    Log-Message "Locating Microsoft Edge user data..."
    $edgeDataDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    $edgeStagingDir = Join-Path -Path $stagingDir.FullName -ChildPath "Edge_User_Data"
    if (Test-Path $edgeDataDir) {
        Copy-Item -Path $edgeDataDir -Destination $edgeStagingDir -Recurse -Force
        Log-Message "Successfully copied Edge data to staging area." -Level "SUCCESS"
    } else {
        Log-Message "Edge user data directory not found, skipping." -Level "WARN"
    }

    # --- STEP 5: CREATE A SINGLE BACKUP ARCHIVE ---
    $archiveName = "RDP_Profile_Backup_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').zip"
    $archivePath = Join-Path -Path $env:TEMP -ChildPath $archiveName
    if (Test-Path $archivePath) { Remove-Item $archivePath }
    Compress-Archive -Path "$($stagingDir.FullName)\*" -DestinationPath $archivePath
    $fileSize = (Get-Item $archivePath).Length / 1MB
    Log-Message "Created final backup archive at $archivePath (Size: $($fileSize.ToString('F2')) MB)" -Level "SUCCESS"

    # --- STEP 6: UPLOAD TO GITHUB RELEASE ---
    Log-Message "Uploading backup archive to GitHub Release '$releaseTag'..."
    $env:GH_TOKEN = $pat
    
    # Create the release. If it exists, this command updates it.
    gh release create $releaseTag --repo "$githubUsername/$repositoryName" --title "RDP Profile Backup" --notes "Latest automated RDP profile backup." --prerelease --target main

    # Upload the asset. The --clobber flag overwrites the file if it already exists on the release.
    gh release upload $releaseTag $archivePath --repo "$githubUsername/$repositoryName" --clobber
    
    Log-Message "Backup successfully uploaded to GitHub." -Level "SUCCESS"

} catch {
    Log-Message "An error occurred during the backup process: $($_.Exception.Message)" -Level "ERROR"
} finally {
    # --- STEP 7: CLEANUP ---
    Log-Message "Cleaning up temporary staging directory..."
    Remove-Item -Path $stagingDir.FullName -Recurse -Force
    if (Test-Path $archivePath) { Remove-Item $archivePath }
    Log-Message "Cleanup complete."
}
