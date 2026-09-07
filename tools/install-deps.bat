@echo off
setlocal EnableExtensions
chcp 65001 >nul
title XShark 依赖安装
cd /d "%~dp0"

set "LOG=%~dp0xshark-deps.log"
set "SCRIPT=%~dp0xshark-install-deps.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0..\tools\xshark-install-deps.ps1"

if not exist "%SCRIPT%" (
  echo 找不到 xshark-install-deps.ps1
  echo 日志将无法写入依赖脚本。
  pause
  exit /b 1
)

echo 日志: %LOG%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -LogFile "%LOG%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo 安装未完全成功，退出码 %RC%
  echo 请打开日志查看详情: %LOG%
  pause
)
exit /b %RC%
