@echo off
setlocal EnableExtensions
chcp 65001 >nul
title XShark Launcher
cd /d "%~dp0"

set "LOG=%~dp0xshark-launch.log"
echo ===== %DATE% %TIME% =====>> "%LOG%"
echo cwd=%CD%>> "%LOG%"
echo bat=%~f0>> "%LOG%"

set "PS1=%~dp0xshark-install-deps.ps1"
if not exist "%PS1%" set "PS1=%~dp0..\tools\xshark-install-deps.ps1"

if not exist "%PS1%" (
  echo [ERROR] 找不到 xshark-install-deps.ps1
  echo [ERROR] 找不到 xshark-install-deps.ps1>> "%LOG%"
  echo 日志: %LOG%
  pause
  exit /b 1
)

echo using=%PS1%>> "%LOG%"
echo 正在检查依赖并启动 XShark...
echo 日志:
echo   %LOG%
echo   %~dp0xshark-deps.log

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -LaunchAfter -LogFile "%~dp0xshark-deps.log"
set "RC=%ERRORLEVEL%"
echo exit_code=%RC%>> "%LOG%"

if not "%RC%"=="0" (
  echo.
  echo [失败] 退出码 %RC%
  echo 请查看:
  echo   %LOG%
  echo   %~dp0xshark-deps.log
  echo   %~dp0xshark-app.log
  echo.
  pause
  exit /b %RC%
)

exit /b 0
