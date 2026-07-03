@echo off
:: Check for Administrator privileges and elevate if needed
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :mainMenu
) else (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:mainMenu
cd /d "%~dp0"
cls
color 0F
echo ===========================================
echo       WINDHAWK MANAGEMENT TOOLBOX
echo ===========================================
echo.
echo  [1] Backup Windhawk Configuration
echo  [2] Restore Windhawk Configuration
echo  [3] Exit
echo.
echo ===========================================
set /p "menu_choice=Please enter your choice (1-3): "

if "%menu_choice%" == "1" goto :confirmBackup
if "%menu_choice%" == "2" goto :confirmRestore
if "%menu_choice%" == "3" exit /b
goto :mainMenu

:confirmBackup
cls
color 0F
echo === WINDHAWK BACKUP SYSTEM ===
echo.
echo [Y] Yes (Proceed) / [N] No (Go Back to Main Menu)
set /p "first_confirm=Are you sure you want to backup Windhawk configs?: "
if /i "%first_confirm%" neq "Y" goto :mainMenu

:: Existing Backup Check
if not exist "windhawk-config-archive.zip" goto :runBackup

cls
color 0E
echo WARNING: A backup file ('windhawk-config-archive.zip') already exists!
echo Creating a new backup will COMPLETELY OVERWRITE the old one.
echo.
echo [Y] Yes (Overwrite) / [N] No (Go Back to Main Menu)
set /p "overwrite_confirm=Do you want to proceed?: "
if /i "%overwrite_confirm%" neq "Y" goto :mainMenu

:runBackup
cls
color 0F
echo Collecting Windhawk data and packaging, please wait...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ArchiveFile = 'windhawk-config-archive.zip'; $TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; $WindhawkDir = \"$env:PROGRAMDATA\Windhawk\"; $CollectedModsDir = Join-Path $TempDir 'Mods'; Copy-Item \"$WindhawkDir\Engine\Mods\" -Destination \"$CollectedModsDir\Engine\Mods\" -Recurse -Force; Copy-Item \"$WindhawkDir\ModsSource\" -Destination \"$CollectedModsDir\ModsSource\" -Recurse -Force; $CollectedRegDir = Join-Path $TempDir 'Reg'; New-Item -Path $CollectedRegDir -ItemType Directory -Force | Out-Null; reg export \"HKLM\SOFTWARE\Windhawk\Engine\Mods\" \"$CollectedRegDir\Engine-Mods.reg\" /y | Out-Null; reg export \"HKLM\SOFTWARE\Windhawk\Engine\ModsWritable\" \"$CollectedRegDir\Engine-ModsWritable.reg\" /y | Out-Null; $Items = Get-ChildItem -Path $TempDir -Force | ForEach-Object { $_.FullName }; Compress-Archive -Path $Items -DestinationPath $ArchiveFile -Force"
color 0A
echo.
echo [SUCCESS] The latest Windhawk backup has been successfully created!
echo.
pause
goto :mainMenu

:confirmRestore
cls
color 0F
:: Check if the backup file exists before asking anything
if not exist "windhawk-config-archive.zip" (
    color 0C
    echo ERROR: 'windhawk-config-archive.zip' was not found in this folder!
    echo Please make sure the backup zip is in the same directory as this script.
    echo.
    pause
    goto :mainMenu
)

echo === WINDHAWK RESTORE SYSTEM ===
echo.
echo WARNING: This action will replace your current Windhawk mods and 
echo registry configuration with the data stored in the backup!
echo.
echo [Y] Yes (Proceed) / [N] No (Go Back to Main Menu)
set /p "restore_confirm=Are you sure you want to restore the backup?: "
if /i "%restore_confirm%" neq "Y" goto :mainMenu

:runRestore
cls
echo Restoring Windhawk backup to the system, please wait...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; Expand-Archive -Path 'windhawk-config-archive.zip' -DestinationPath $TempDir -Force; $WindhawkDir = \"$env:PROGRAMDATA\Windhawk\"; Copy-Item \"$TempDir\Mods\*\" -Destination \"$WindhawkDir\" -Recurse -Force; if (Test-Path \"$TempDir\Reg\Engine-Mods.reg\") { reg import \"$TempDir\Reg\Engine-Mods.reg\" | Out-Null }; if (Test-Path \"$TempDir\Reg\Engine-ModsWritable.reg\") { reg import \"$TempDir\Reg\Engine-ModsWritable.reg\" | Out-Null }; Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue"

color 0A
echo.
echo [SUCCESS] Restore operation completed successfully!
echo You might need to restart Windhawk or log out and log back in for changes to take full effect.
echo.
pause
goto :mainMenu
