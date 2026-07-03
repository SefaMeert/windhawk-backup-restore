Hi everyone,

I wanted to share two robust Batch scripts I put together to completely automate the process of backing up and restoring Windhawk mods, source files, and registry configurations.
Why use these scripts?

    One-Click Run: You don't need to manually open PowerShell as an administrator and navigate to folders. Just double-click the .bat file.

    Auto-Elevation: The scripts automatically detect if they are running with admin privileges. If not, they prompt for UAC elevation by themselves.

    Safety First: They won't blindly overwrite anything. They include confirmation prompts ([Y] Yes / [N] No) before taking any action.

    Fixes Local Directory Issues: They are forced to work within the directory they are executed from, meaning your backup .zip file will always appear right next to the script.

1. Backup Script (windhawk_backup.bat)

This script creates a neat windhawk-config-archive.zip file containing your mods and registry tweaks. If a backup already exists, it will warn you before overwriting it.

`@echo off
:: Check for Administrator privileges and elevate if needed
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :runScript
) else (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:runScript
cd /d "%~dp0"
cls
color 0F

:: Phase 1: Initial Run Confirmation
echo === WINDHAWK BACKUP SYSTEM ===
echo.
echo [Y] Yes / [N] No
set /p "first_confirm=Are you sure you want to backup Windhawk configs?: "
if /i "%first_confirm%" neq "Y" goto :cancelled

:: Phase 2: Existing Backup Check
if not exist "windhawk-config-archive.zip" goto :backup

cls
color 0E
echo WARNING: A backup file ('windhawk-config-archive.zip') already exists in this folder!
echo Creating a new backup will COMPLETELY OVERWRITE the old one.
echo.
echo [Y] Yes / [N] No
set /p "overwrite_confirm=Do you want to proceed and overwrite the old backup?: "
if /i "%overwrite_confirm%" neq "Y" goto :cancelled

:backup
cls
color 0F
echo Collecting Windhawk data and packaging, please wait...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ArchiveFile = 'windhawk-config-archive.zip'; $TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; $WindhawkDir = \"$env:PROGRAMDATA\Windhawk\"; $CollectedModsDir = Join-Path $TempDir 'Mods'; Copy-Item \"$WindhawkDir\Engine\Mods\" -Destination \"$CollectedModsDir\Engine\Mods\" -Recurse -Force; Copy-Item \"$WindhawkDir\ModsSource\" -Destination \"$CollectedModsDir\ModsSource\" -Recurse -Force; $CollectedRegDir = Join-Path $TempDir 'Reg'; New-Item -Path $CollectedRegDir -ItemType Directory -Force | Out-Null; reg export \"HKLM\SOFTWARE\Windhawk\Engine\Mods\" \"$CollectedRegDir\Engine-Mods.reg\" /y | Out-Null; reg export \"HKLM\SOFTWARE\Windhawk\Engine\ModsWritable\" \"$CollectedRegDir\Engine-ModsWritable.reg\" /y | Out-Null; $Items = Get-ChildItem -Path $TempDir -Force | ForEach-Object { $_.FullName }; Compress-Archive -Path $Items -DestinationPath $ArchiveFile -Force"
color 0A
echo.
echo [SUCCESS] The latest Windhawk backup has been successfully created!
pause
exit /b

:cancelled
cls
color 0F
echo Backup process cancelled by user. No changes were made.
echo.
pause
exit /b`

2. Restore Script (windhawk_restore.bat)

Place this script in the same folder as your windhawk-config-archive.zip and double-click it. It prompts for confirmation since it overwrites active system settings.

`@echo off
:: Check for Administrator privileges and elevate if needed
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :runScript
) else (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:runScript
cd /d "%~dp0"
cls
color 0F

:: Phase 1: Check if the backup file exists before asking anything
if not exist "windhawk-config-archive.zip" (
    color 0C
    echo ERROR: 'windhawk-config-archive.zip' was not found in this folder!
    echo Please make sure the backup zip is in the same directory as this script.
    echo.
    pause
    exit /b
)

:: Phase 2: Restore Confirmation
echo === WINDHAWK RESTORE SYSTEM ===
echo.
echo WARNING: This action will replace your current Windhawk mods and 
echo registry configuration with the data stored in the backup!
echo.
echo [Y] Yes / [N] No
set /p "restore_confirm=Are you sure you want to restore the backup?: "
if /i "%restore_confirm%" neq "Y" goto :cancelled

:restore
cls
echo Restoring Windhawk backup to the system, please wait...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; Expand-Archive -Path 'windhawk-config-archive.zip' -DestinationPath $TempDir -Force; $WindhawkDir = \"$env:PROGRAMDATA\Windhawk\"; Copy-Item \"$TempDir\Mods\*\" -Destination \"$WindhawkDir\" -Recurse -Force; if (Test-Path \"$TempDir\Reg\Engine-Mods.reg\") { reg import \"$TempDir\Reg\Engine-Mods.reg\" | Out-Null }; if (Test-Path \"$TempDir\Reg\Engine-ModsWritable.reg\") { reg import \"$TempDir\Reg\Engine-ModsWritable.reg\" | Out-Null }; Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue"

color 0A
echo.
echo [SUCCESS] Restore operation completed successfully!
echo You might need to restart Windhawk or log out and log back in for changes to take full effect.
pause
exit /b

:cancelled
cls
color 0F
echo Restore process cancelled by user. System files were not modified.
echo.
pause
exit /b`


How to use:

    Copy the backup code into a text file and save it as windhawk_backup.bat.

    Copy the restore code into another text file and save it as windhawk_restore.bat.

    Make sure to select All Files (*.*) when saving in Notepad so it doesn't end up as a .txt file.

Hope this helps anyone looking for a clean, unattended-setup-friendly way to hop between machines or reinstall Windows without losing their Windhawk setups!
