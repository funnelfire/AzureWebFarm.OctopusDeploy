if "%ComputeEmulatorRunning%"=="true" goto :EOF

powershell wget https://www.dropbox.com/s/k4k0xsubgqr2g5x/rtools_setup_x64.exe?dl=1 -OutFile rtools_setup_x64.exe
start /wait rtools_setup_x64.exe /install /passive /norestart
start /wait "Remote Debugger Computer Prep" "%PROGRAMFILES%\Microsoft Visual Studio 12.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" /prepcomputer /domain /private /public /quiet
start "Remote Debugger" "%PROGRAMFILES%\Microsoft Visual Studio 12.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" /noauth /anyuser /nosecuritywarn /silent /timeout 2147483646

EXIT /B 0