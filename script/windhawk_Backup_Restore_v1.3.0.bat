@echo off
setlocal enabledelayedexpansion

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
echo Version 1.3
echo https://github.com/SefaMeert/windhawk-backup-restore
echo.
echo ========================================================
echo                WINDHAWK BACKUP and RESTORE
echo ========================================================
echo.
echo    [1] Backup Windhawk Configuration
echo.
echo    [2] Restore Windhawk Configuration
echo.
echo    [3] Exit
echo.
echo ========================================================
echo.
echo Please enter your choice (1-3): 

choice /c 123 /n
set "menu_choice=%errorlevel%"

if "%menu_choice%"=="1" goto :confirmBackup
if "%menu_choice%"=="2" goto :listBackups
if "%menu_choice%"=="3" exit /b
goto :mainMenu

:confirmBackup
cls
color 0F
echo ========================================================
echo                WINDHAWK BACKUP SYSTEM
echo ========================================================
echo.
echo Creating a new timestamped backup in:
color 0E
echo    "%~dp0"
color 0F
echo.
echo --------------------------------------------------------
echo.
echo    [Y] Yes (Proceed)  ^|  [N] No (Go Back to Main Menu)
echo.
echo --------------------------------------------------------
echo.
echo Are you sure you want to backup Windhawk configs? (Y/N): 

choice /c YN /n
if %errorlevel% neq 1 goto :mainMenu

:runBackup
cls
color 0F
echo ========================================================
echo                  BACKUP IN PROGRESS...
echo ========================================================
echo.
echo Stopping Windhawk service, collecting data, and packaging...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$TimeStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'; $ArchiveFile = Join-Path '%~dp0' \"windhawk-backup-$TimeStamp.zip\"; $TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; Stop-Service WindhawkService -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; $WindhawkDataDir = \"$env:PROGRAMDATA\Windhawk\"; $CollectedModsDir = Join-Path $TempDir 'ProgramData_Windhawk'; if (Test-Path $WindhawkDataDir) { Copy-Item $WindhawkDataDir -Destination $CollectedModsDir -Recurse -Force -ErrorAction SilentlyContinue }; $CollectedRegDir = Join-Path $TempDir 'Reg'; New-Item -Path $CollectedRegDir -ItemType Directory -Force | Out-Null; reg export \"HKLM\SOFTWARE\Windhawk\" \"$CollectedRegDir\HKLM_Windhawk.reg\" /y | Out-Null; reg export \"HKCU\Software\Windhawk\" \"$CollectedRegDir\HKCU_Windhawk.reg\" /y | Out-Null; Start-Service WindhawkService -ErrorAction SilentlyContinue; $Items = Get-ChildItem -Path $TempDir -Force | ForEach-Object { $_.FullName }; Compress-Archive -Path $Items -DestinationPath $ArchiveFile -Force; Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue"

color 0A
echo ========================================================
echo                   SUCCESS!
echo ========================================================
echo.
echo The Windhawk backup has been successfully created!
echo.
echo Press any key to return to the main menu...
pause >nul
goto :mainMenu

:listBackups
cls
color 0F
echo ========================================================
echo                SELECT A BACKUP TO RESTORE
echo ========================================================
echo.

set "count=0"
for /f "delims=" %%F in ('dir /b /o:-d "windhawk-backup-*.zip" 2^>nul') do (
    set /a count+=1
    set "file[!count!]=%%F"
    echo    [!count!] %%F
)

if exist "windhawk-config-archive.zip" (
    set /a count+=1
    set "file[!count!]=windhawk-config-archive.zip"
    echo    [!count!] windhawk-config-archive.zip (Legacy Backup)
)

if %count%==0 (
    color 0C
    echo ========================================================
    echo                        ERROR!
    echo ========================================================
    echo.
    echo No backup files found in:
    echo    "%~dp0"
    echo.
    echo Press any key to return to the main menu...
    pause >nul
    goto :mainMenu
)

echo.
echo    [0] Cancel (Go Back to Main Menu)
echo.
echo --------------------------------------------------------
echo.
set /p "restore_choice=Enter choice number (0-%count%): "

if "%restore_choice%"=="0" goto :mainMenu
if not defined file[%restore_choice%] (
    echo Invalid choice. Try again.
    timeout /t 2 >nul
    goto :listBackups
)

set "selected_backup=!file[%restore_choice%]!"

:confirmRestore
cls
color 0F
echo ========================================================
echo                WINDHAWK RESTORE SYSTEM
echo ========================================================
echo.
color 0E
echo WARNING: This action will replace your current Windhawk mods
echo and registry configuration with the selected backup!
color 0F
echo.
echo Backup File Selected:
color 0E
echo    "!selected_backup!"
color 0F
echo.
echo --------------------------------------------------------
echo.
echo    [Y] Yes (Proceed)  ^|  [N] No (Go Back to Main Menu)
echo.
echo --------------------------------------------------------
echo.
echo Are you sure you want to restore this backup? (Y/N): 

choice /c YN /n
if %errorlevel% neq 1 goto :mainMenu

:runRestore
cls
color 0F
echo ========================================================
echo                 RESTORE IN PROGRESS...
echo ========================================================
echo.
echo Stopping Windhawk service, restoring files and registry...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ArchiveFile = Join-Path '%~dp0' '!selected_backup!'; $TempDir = Join-Path $env:TEMP ([guid]::NewGuid()); New-Item -ItemType Directory -Path $TempDir | Out-Null; Expand-Archive -Path $ArchiveFile -DestinationPath $TempDir -Force; Stop-Service WindhawkService -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; $WindhawkDataDir = \"$env:PROGRAMDATA\Windhawk\"; $SourceModsDir = Join-Path $TempDir 'ProgramData_Windhawk'; if (Test-Path $SourceModsDir) { if (!(Test-Path $WindhawkDataDir)) { New-Item -ItemType Directory -Path $WindhawkDataDir -Force | Out-Null }; Copy-Item \"$SourceModsDir\*\" -Destination $WindhawkDataDir -Recurse -Force -ErrorAction SilentlyContinue }; if (Test-Path \"$TempDir\Reg\HKLM_Windhawk.reg\") { reg import \"$TempDir\Reg\HKLM_Windhawk.reg\" | Out-Null }; if (Test-Path \"$TempDir\Reg\HKCU_Windhawk.reg\") { reg import \"$TempDir\Reg\HKCU_Windhawk.reg\" | Out-Null }; Start-Service WindhawkService -ErrorAction SilentlyContinue; Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue"

color 0A
echo ========================================================
echo                   SUCCESS!
echo ========================================================
echo.
echo Restore operation completed successfully!
echo.
echo NOTE: You might need to restart Windhawk or log out and
echo log back in for changes to take full effect.
echo.
echo Press any key to return to the main menu...
pause >nul
goto :mainMenu
