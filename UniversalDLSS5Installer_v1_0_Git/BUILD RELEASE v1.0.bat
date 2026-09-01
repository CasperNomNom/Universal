@echo off
setlocal
cd /d "%~dp0"
title Universal DLSS 5 Installer v1.11 - Build Release
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Release-v1.0.ps1"
if errorlevel 1 (
    echo.
    echo BUILD FAILED.
    pause
    exit /b 1
)
endlocal
