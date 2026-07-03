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
exit /b
