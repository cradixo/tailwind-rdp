<#
.SYNOPSIS
    Backs up the complete user profile (Full Registry and Edge data) to a GitHub Release.
.DESCRIPTION
    ACTION REQUIRED: You must hardcode your GitHub Personal Access Token in the '$pat' variable below.
    The script gathers all user settings, creates a single ZIP archive,
    and uses the GitHub CLI (gh) to upload it as a release asset, overwriting the previous backup.
#>

# --- ‼️ ACTION REQUIRED: CONFIGURE YOUR PERSONAL ACCESS TOKEN HERE ‼️ ---
# Generate a token with 'repo' scope from your GitHub developer settings.
$pat = "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" # <-- PASTE YOUR TOKEN HERE

# --- Configuration ---
$githubUsername = "cradixo"
$repositoryName = "tailwind-rdp"
$releaseTag = "latest-rdp-profile"

# --- Function for Detailed Logging ---
function Log-Message {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# --- Script Body ---
# Create a temporary staging area for the backup files
$stagingDir = New-Item -Path $env:TEMP -Name "RdpBackup_$(Get-Random)" -ItemType Directory
$archivePath = $null # Initialize to prevent cleanup errors
Log-Message "Created temporary staging directory at $($stagingDir.FullName)"

try {
    # --- STEP 1: VERIFY REQUIREMENTS ---
    Log-Message "Verifying requirements..."
    if ($pat -eq "ghp_YourPersonalAccessTokenHere" -or -not $pat.StartsWith("ghp_")) {
        throw "CRITICAL: The Personal Access Token has not been configured in the script. Please edit backup.ps1."
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "CRITICAL: GitHub CLI ('gh') is not installed or not in PATH."
    }
    Log-Message "GitHub CLI and authentication token are present." -Level "SUCCESS"

    # --- STEP 2: CLOSE MICROSOFT EDGE ---
    Log-Message "Ensuring Microsoft Edge is closed to prevent data corruption..."
    Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -Verbose
    Start-Sleep -Seconds 3

    # --- STEP 3: FULL USER REGISTRY BACKUP ---
    Log-Message "Performing full backup of user registry (HKEY_CURRENT_USER)..."
    $regFile = Join-Path -Path $stagingDir.FullName -ChildPath "full_user_profile.reg"
    reg export HKCU $regFile /y
    if ((Get-Item $regFile).Length -gt 1MB) {
        Log-Message "Successfully exported user registry." -Level "SUCCESS"
    } else {
        throw "Failed to export user registry; the resulting file is too small."
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
    
    # Create the release. If it exists, this command does nothing but is safe to run.
    gh release create $releaseTag --repo "$githubUsername/$repositoryName" --title "RDP Profile Backup" --notes "Latest automated RDP profile backup." --prerelease --target main
    
    # Upload the asset. The --clobber flag overwrites the file if it already exists.
    gh release upload $releaseTag $archivePath --repo "$githubUsername/$repositoryName" --clobber
    
    Log-Message "Backup successfully uploaded to GitHub." -Level "SUCCESS"

} catch {
    Log-Message "An error occurred during the backup process: $($_.Exception.Message)" -Level "ERROR"
} finally {
    # --- STEP 7: CLEANUP ---
    Log-Message "Cleaning up temporary files..."
    Remove-Item -Path $stagingDir.FullName -Recurse -Force
    if (-not [string]::IsNullOrWhiteSpace($archivePath) -and (Test-Path $archivePath)) {
        Remove-Item $archivePath
    }
    Log-Message "Cleanup complete."
}
