#
# install.ps1 - The Persistence Agent Installer
# This script is run by the GitHub Actions workflow to set up the environment.
#
param (
    [string]$RdpUser,
    [string]$RdpPass,
    [string]$GitPat,
    [string]$RepoPath
)

Write-Host "--- Starting Persistence Agent Installation ---"

# --- 1. Define Core Paths ---
$BackupStoragePath = Join-Path $RepoPath "rdp-backups"
$ScriptsPath = "C:\ProgramData\RDP-Agent" # A neutral, system-wide location for the scripts
$UserHome = "C:\Users\$RdpUser"
$UserStartupPath = Join-Path $UserHome "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null
Write-Host "Scripts will be stored in $ScriptsPath"

# --- 2. Configure Git Authentication for the RDP User ---
# This allows the backup task to push to your private repository.
$GitCredsContent = "https://$($RdpUser):$($GitPat)@github.com"
New-Item -Path (Join-Path $UserHome ".git-credentials") -ItemType File -Value $GitCredsContent -Force
git config --global user.name "RDP Backup Bot"
git config --global user.email "actions-bot@github.com"
# This tells Git to use the .git-credentials file we just created
git config --global credential.helper "store --file=C:/Users/$RdpUser/.git-credentials"


# --- 3. Create the Restore Script (runs once at login) ---
$RestoreScriptContent = @"
# This script runs automatically when you log in to restore your last session.
# It will self-destruct after running once.
Write-Host '--- Restoring User Session ---'
# Restore Edge Profile using rclone
rclone copy `"$BackupStoragePath\Edge`" `"$env:LOCALAPPDATA\Microsoft\Edge`" --create-empty-src-dirs
# Restore Registry Settings
Get-ChildItem -Path `"$BackupStoragePath\Registry`" -Filter *.reg | ForEach-Object { reg import `"`$_.FullName`" }
Write-Host '--- Restore Complete ---'
Remove-Item -Path `"`$MyInvocation.MyCommand.Path`" -Force
"@
# Only deploy the restore script if a backup actually exists
if (Test-Path $BackupStoragePath) {
    New-Item -Path $UserStartupPath -ItemType Directory -Force | Out-Null
    Set-Content -Path (Join-Path $UserStartupPath "restore.ps1") -Value $RestoreScriptContent
    Write-Host "Restore script deployed to user's startup folder."
}


# --- 4. Create the Backup Script (runs every minute via Task Scheduler) ---
$BackupScriptContent = @"
# This script is run by the Task Scheduler every minute to back up changes.
Set-Location -Path `"$RepoPath`"
# Ensure we have the latest changes before backing up
git pull
# 1. Backup Registry
New-Item -Path `"$BackupStoragePath\Registry`" -ItemType Directory -Force | Out-Null
reg export HKCU\Software\Microsoft\Windows\CurrentVersion\Themes "`$BackupStoragePath\Registry\Themes.reg`" /y
reg export "HKCU\Control Panel\Desktop" "`$BackupStoragePath\Registry\Desktop.reg`" /y
# 2. Backup Edge Data using rclone (this is very fast and only syncs changes)
rclone sync `"`$env:LOCALAPPDATA\Microsoft\Edge\User Data`" `"`$BackupStoragePath\Edge\User Data`" --create-empty-src-dirs
# 3. Commit and Push changes to GitHub
git add `"$BackupStoragePath\*`"
if (git status --porcelain) {
    git commit -m "sync: RDP session backup @ `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`"
    git push
}
"@
Set-Content -Path (Join-Path $ScriptsPath "backup.ps1") -Value $BackupScriptContent
Write-Host "Backup script created at $($ScriptsPath)\backup.ps1"


# --- 5. Create the Scheduled Task to run the backup script ---
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$($ScriptsPath)\backup.ps1`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Repetition = New-ScheduledTaskRepetition -Duration (New-TimeSpan -Days 9999) -Interval (New-TimeSpan -Minutes 1)
$Trigger.Repetition = $Repetition
$Principal = New-ScheduledTaskPrincipal -UserId $RdpUser -LogonType Interactive
Register-ScheduledTask -TaskName "RDP_User_Backup" -Action $Action -Trigger $Trigger -Principal $Principal -Force
Write-Host "Scheduled task 'RDP_User_Backup' created to run every 1 minute."

Write-Host "--- Persistence Agent Installation Complete ---"
