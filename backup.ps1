<#
.SYNOPSIS
    Backs up Windows theme settings and Microsoft Edge user data to a Git repository.
    This script is modified by the GitHub Actions workflow to include the necessary credentials.
#>

# --- Configuration ---
$githubUsername = "cradixo"
$repositoryName = "tailwind-rdp"
# This placeholder will be replaced by the GitHub Actions workflow. Do not modify it.
$pat = "GIT_PAT_PLACEHOLDER" 

# --- Paths ---
$userProfile = $env:USERPROFILE
$backupDir = Join-Path -Path $userProfile -ChildPath "Documents\RDP_Backup"
$logFile = Join-Path -Path $backupDir -ChildPath "backup_log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$edgeDataDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
$regFileTheme = Join-Path -Path $backupDir -ChildPath "theme_settings.reg"
$gitRepoPath = Join-Path -Path $backupDir -ChildPath "repo"

# --- Script Body ---
Start-Transcript -Path $logFile -Append

Write-Host "----------------------------------------------------"
Write-Host "Starting RDP Backup Process at $(Get-Date)"
Write-Host "----------------------------------------------------"

if ($pat -eq "GIT_PAT_PLACEHOLDER" -or [string]::IsNullOrWhiteSpace($pat)) {
    Write-Error "CRITICAL: The GIT_PAT placeholder was not replaced. Cannot push to GitHub. This is an error in the workflow."
    Stop-Transcript
    exit 1
}

# 1. Prepare Backup Directory
Write-Host "[STEP 1/6] Preparing backup directory..."
if (Test-Path $gitRepoPath) {
    Write-Host "  - Removing old repository clone."
    Remove-Item -Path $gitRepoPath -Recurse -Force
}
if (-not (Test-Path $backupDir)) {
    Write-Host "  - Creating backup directory at $backupDir"
    New-Item -Path $backupDir -ItemType Directory | Out-Null
}
Write-Host "  - SUCCESS: Backup directory is ready."

# 2. Close Microsoft Edge to prevent data corruption
Write-Host "[STEP 2/6] Closing Microsoft Edge..."
$edgeProcesses = Get-Process msedge -ErrorAction SilentlyContinue
if ($edgeProcesses) {
    $edgeProcesses | Stop-Process -Force
    Write-Host "  - SUCCESS: Microsoft Edge has been terminated."
    Start-Sleep -Seconds 3 # A small delay to ensure file locks are released
} else {
    Write-Host "  - INFO: Microsoft Edge was not running."
}

# 3. Backup Theme Registry Settings
Write-Host "[STEP 3/6] Backing up theme settings from HKCU registry..."
try {
    reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes" $regFileTheme /y
    Write-Host "  - SUCCESS: Exported theme settings to $regFileTheme"
} catch {
    Write-Error "  - FAILED: Could not export registry settings. Error: $_"
    Stop-Transcript
    exit 1
}

# 4. Backup Microsoft Edge Data
Write-Host "[STEP 4/6] Backing up Microsoft Edge data..."
try {
    Compress-Archive -Path "$edgeDataDir\*" -DestinationPath "$backupDir\edge_data.zip" -Force
    Write-Host "  - SUCCESS: Compressed Edge data to edge_data.zip"
} catch {
    Write-Error "  - FAILED: Could not compress Edge data. It might be in use. Error: $_"
    Stop-Transcript
    exit 1
}

# 5. Clone repository to commit to
Write-Host "[STEP 5/6] Cloning GitHub repository..."
git clone "https://oauth2:$pat@github.com/$githubUsername/$repositoryName.git" $gitRepoPath
cd $gitRepoPath

# 6. Commit and Push to GitHub
Write-Host "[STEP 6/6] Committing and pushing backup to GitHub..."
Write-Host "  - Moving backup files into the repository..."
Move-Item -Path $regFileTheme -Destination $gitRepoPath -Force
Move-Item -Path "$backupDir\edge_data.zip" -Destination $gitRepoPath -Force

# --- KEY CHANGE IS HERE ---
# Stop logging to release the lock on the log file BEFORE moving it.
Write-Host "  - Finalizing log file..."
Stop-Transcript

# Now that the file is unlocked, move it into the repo.
Move-Item -Path $logFile -Destination $gitRepoPath -Force
# --- END OF KEY CHANGE ---

git config --global user.email "rdp-backup@github.com"
git config --global user.name "RDP Backup Action"
git add .

if (-not (git diff --staged --quiet)) {
    git commit -m "RDP Backup - $(Get-Date)"
    git push
}

Write-Host "----------------------------------------------------"
Write-Host "Backup and upload process finished successfully at $(Get-Date)"
Write-Host "----------------------------------------------------"
