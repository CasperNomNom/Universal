@echo off
setlocal EnableExtensions
title Universal DLSS 5 Installer - Push to GitHub
cd /d "%~dp0"
set "SOURCE_DIR=%CD%"
set "REPO_URL=https://github.com/CasperNomNom/Universal.git"

where git >nul 2>nul
if errorlevel 1 (
    echo Git for Windows was not found.
    echo Install it from https://git-scm.com/download/win and run this file again.
    pause
    exit /b 1
)

if not exist "%SOURCE_DIR%\UniversalDLSS5Installer_v1_0.ps1" (
    echo Place this BAT beside UniversalDLSS5Installer_v1_0.ps1 and run it again.
    pause
    exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>nul
if not errorlevel 1 goto :push_existing

set "CLONE_ROOT=%TEMP%\Universal-GitHub-Push-%RANDOM%-%RANDOM%"
echo Creating a temporary GitHub working copy...
git clone "%REPO_URL%" "%CLONE_ROOT%"
if errorlevel 1 goto :failed
if not exist "%CLONE_ROOT%\UniversalDLSS5Installer_v1_0_Git" mkdir "%CLONE_ROOT%\UniversalDLSS5Installer_v1_0_Git"
echo Copying the updated project...
robocopy "%SOURCE_DIR%" "%CLONE_ROOT%\UniversalDLSS5Installer_v1_0_Git" /E /R:1 /W:1 /XD .git Installer\Output Logs /XF *.exe *.log >nul
if errorlevel 8 goto :failed
cd /d "%CLONE_ROOT%"
goto :commit_and_push

:push_existing
for /f "delims=" %%R in ('git rev-parse --show-toplevel') do cd /d "%%R"

:commit_and_push
git remote get-url origin >nul 2>nul
if errorlevel 1 git remote add origin "%REPO_URL%"
if errorlevel 1 goto :failed
git config user.name >nul 2>nul
if errorlevel 1 git config user.name "CasperNomNom"
git config user.email >nul 2>nul
if errorlevel 1 git config user.email "117864644+CasperNomNom@users.noreply.github.com"
git add -A
git diff --cached --quiet
if not errorlevel 1 goto :nothing_to_commit
set /p "COMMIT_MESSAGE=Commit message [Update Universal DLSS 5 Installer]: "
if not defined COMMIT_MESSAGE set "COMMIT_MESSAGE=Update Universal DLSS 5 Installer"
git commit -m "%COMMIT_MESSAGE%"
if errorlevel 1 goto :failed

:nothing_to_commit
echo Pushing main to GitHub...
git push -u origin main
if errorlevel 1 goto :failed
git push origin --tags
if errorlevel 1 goto :failed
echo.
echo Push completed successfully.
if defined CLONE_ROOT echo Temporary Git working copy: %CLONE_ROOT%
pause
exit /b 0

:failed
echo.
echo Push failed. Review the message above.
echo Git may open a browser so you can sign in to GitHub.
if defined CLONE_ROOT echo Temporary Git working copy: %CLONE_ROOT%
pause
exit /b 1
