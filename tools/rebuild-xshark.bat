@echo off
setlocal
REM Rebuild XShark GUI with MSVC/SDK paths (VsDevCmd is unreliable in some shells).
set "VS=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools"
set "MSVC=%VS%\VC\Tools\MSVC\14.51.36231"
set "SDKVER=10.0.26100.0"
set "INCLUDE=%MSVC%\include;C:\Program Files (x86)\Windows Kits\10\Include\%SDKVER%\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\%SDKVER%\shared;C:\Program Files (x86)\Windows Kits\10\Include\%SDKVER%\um;C:\Program Files (x86)\Windows Kits\10\Include\%SDKVER%\winrt"
set "LIB=%MSVC%\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\%SDKVER%\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\Lib\%SDKVER%\um\x64"
set "PATH=%MSVC%\bin\Hostx64\x64;%VS%\MSBuild\Current\Bin;C:\Program Files (x86)\Windows Kits\10\bin\%SDKVER%\x64;C:\Program Files\CMake\bin;%PATH%"

cd /d F:\wireshark\build
cmake --build . --target wireshark copy_data_files -j 8
exit /b %ERRORLEVEL%
