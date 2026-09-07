@echo off
setlocal
set "SRC=F:\wireshark"
set "BUILD=%SRC%\build"
set "QT=F:\Qt\6.8.3\msvc2022_64"
set "WIRESHARK_BASE_DIR=F:\Development\wireshark-x64-libs"

echo Stopping XShark / Wireshark if running...
taskkill /F /IM Wireshark.exe 2>nul
taskkill /F /IM dumpcap.exe 2>nul

echo Reconfiguring (Release + LTO, XShark / 小鲨鱼 build)...
cmake -S "%SRC%" -B "%BUILD%" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DENABLE_LTO=ON ^
  -DBUILD_wireshark=ON ^
  -DBUILD_stratoshark=OFF ^
  -DCMAKE_PREFIX_PATH="%QT%"

echo Building XShark GUI + dumpcap...
cmake --build "%BUILD%" --target wireshark dumpcap -j

echo Deploying Qt runtime...
"%QT%\bin\windeployqt.exe" "%BUILD%\run\Wireshark.exe"

echo Done. Run: %SRC%\run-wireshark.bat
endlocal
