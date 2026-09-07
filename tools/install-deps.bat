@echo off
chcp 65001 >nul
title XShark 依赖安装
cd /d "%~dp0"

REM Prefer copy next to this bat (portable package layout)
set "SCRIPT=%~dp0xshark-install-deps.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0..\tools\xshark-install-deps.ps1"
if not exist "%SCRIPT%" (
  echo 找不到 xshark-install-deps.ps1
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %ERRORLEVEL%
