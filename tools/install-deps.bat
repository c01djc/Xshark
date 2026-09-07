@echo off
setlocal EnableExtensions
title XShark deps
cd /d "%~dp0"

set "LOG=%~dp0xshark-deps.log"
set "SCRIPT=%~dp0xshark-install-deps.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0..\tools\xshark-install-deps.ps1"

if not exist "%SCRIPT%" (
  echo missing xshark-install-deps.ps1
  pause
  exit /b 1
)

echo Log: %LOG%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -LogFile "%LOG%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo Install not fully successful, exit %RC%
  echo See log: %LOG%
  pause
)
exit /b %RC%
