@echo off
setlocal EnableExtensions
title XShark
cd /d "%~dp0" 2>nul

REM Always write logs to BOTH package dir and %%TEMP%% so flash-exit still leaves a trail.
set "LOG1=%~dp0xshark-launch.log"
set "LOG2=%TEMP%\xshark-launch.log"

call :log ===== %DATE% %TIME% =====
call :log bat=%~f0
call :log cwd=%CD%
call :log user=%USERNAME%

where powershell.exe >nul 2>&1
if errorlevel 1 (
  call :log ERROR powershell.exe not found in PATH
  echo [ERROR] 找不到 powershell.exe
  echo 日志: %LOG1%
  echo       %LOG2%
  pause
  exit /b 1
)

set "PS1=%~dp0xshark-install-deps.ps1"
if not exist "%PS1%" (
  call :log ERROR missing %PS1%
  echo [ERROR] 缺少 xshark-install-deps.ps1
  echo 请重新下载完整便携包（不要只拷贝 exe）。
  echo 日志: %LOG1%
  echo       %LOG2%
  pause
  exit /b 1
)

if not exist "%~dp0XShark.exe" (
  call :log ERROR missing XShark.exe
  echo [ERROR] 缺少 XShark.exe
  echo 日志: %LOG1%
  pause
  exit /b 1
)

echo 正在启动 XShark...
echo 日志会写入:
echo   %LOG1%
echo   %LOG2%
echo   %~dp0xshark-deps.log
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -LaunchAfter -LogFile "%~dp0xshark-deps.log"
set "RC=%ERRORLEVEL%"
call :log exit_code=%RC%

if not "%RC%"=="0" (
  echo.
  echo [失败] 退出码 %RC%
  echo 正在打开日志...
  if exist "%~dp0xshark-deps.log" start "" notepad.exe "%~dp0xshark-deps.log"
  if exist "%LOG1%" start "" notepad.exe "%LOG1%"
  if exist "%LOG2%" start "" notepad.exe "%LOG2%"
  echo.
  pause
  exit /b %RC%
)

exit /b 0

:log
echo %*>> "%LOG1%" 2>nul
echo %*>> "%LOG2%" 2>nul
goto :eof
