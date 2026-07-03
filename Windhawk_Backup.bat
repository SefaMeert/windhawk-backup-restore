@echo off
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
exit /b
