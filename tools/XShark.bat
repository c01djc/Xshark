@echo off
setlocal EnableExtensions
title XShark
cd /d "%~dp0"

set "LOG1=%~dp0xshark-launch.log"
set "LOG2=%TEMP%\xshark-launch.log"

call :log ===== %DATE% %TIME% =====
call :log bat=%~f0
call :log cwd=%CD%

where powershell.exe >nul 2>&1
if errorlevel 1 (
  call :log ERROR powershell.exe not found
  echo [ERROR] powershell.exe not found
  echo Log: %LOG1%
  echo      %LOG2%
  pause
  exit /b 1
)

set "PS1=%~dp0xshark-install-deps.ps1"
if not exist "%PS1%" (
  call :log ERROR missing xshark-install-deps.ps1
  echo [ERROR] missing xshark-install-deps.ps1
  echo Please re-download the full portable zip.
  echo Log: %LOG1%
  pause
  exit /b 1
)

if not exist "%~dp0XShark.exe" (
  call :log ERROR missing XShark.exe
  echo [ERROR] missing XShark.exe
  echo Log: %LOG1%
  pause
  exit /b 1
)

echo Starting XShark...
echo Logs:
echo   %LOG1%
echo   %LOG2%
echo   %~dp0xshark-deps.log
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -LaunchAfter -LogFile "%~dp0xshark-deps.log"
set "RC=%ERRORLEVEL%"
call :log exit_code=%RC%

if not "%RC%"=="0" (
  echo.
  echo [FAIL] exit code %RC%
  echo Opening logs...
  if exist "%~dp0xshark-deps.log" start "" notepad.exe "%~dp0xshark-deps.log"
  if exist "%LOG1%" start "" notepad.exe "%LOG1%"
  if exist "%LOG2%" start "" notepad.exe "%LOG2%"
  echo.
  pause
  exit /b %RC%
)

exit /b 0

:log
echo %*>>"%LOG1%" 2>nul
echo %*>>"%LOG2%" 2>nul
goto :eof
