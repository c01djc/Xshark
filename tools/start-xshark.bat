@echo off
setlocal EnableExtensions
title XShark Launcher
cd /d "%~dp0"

set "LOG=%~dp0xshark-launch.log"
echo ===== %DATE% %TIME% =====>>"%LOG%"
echo cwd=%CD%>>"%LOG%"
echo bat=%~f0>>"%LOG%"

set "PS1=%~dp0xshark-install-deps.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\tools\xshark-install-deps.ps1"

if not exist "%PS1%" (
  echo [ERROR] missing xshark-install-deps.ps1
  echo [ERROR] missing xshark-install-deps.ps1>>"%LOG%"
  echo Log: %LOG%
  pause
  exit /b 1
)

echo using=%PS1%>>"%LOG%"
echo Starting XShark...
echo Logs:
echo   %LOG%
echo   %~dp0xshark-deps.log

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -LaunchAfter -LogFile "%~dp0xshark-deps.log"
set "RC=%ERRORLEVEL%"
echo exit_code=%RC%>>"%LOG%"

if not "%RC%"=="0" (
  echo.
  echo [FAIL] exit code %RC%
  echo Check logs:
  echo   %LOG%
  echo   %~dp0xshark-deps.log
  echo   %~dp0xshark-app.log
  echo.
  pause
  exit /b %RC%
)

exit /b 0
