@echo off
setlocal
title PC Hub Scanner
color 0B
echo.
echo Starting PC Hub hardware scanner...
echo Your already-open PC Hub tab will detect it automatically.
echo This window does NOT open another browser tab.
echo.
set "PCH_SCRIPT=%TEMP%\PC-Companion.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Naman123u/PC-Benchmark-Hub/main/PC-Companion.ps1' -OutFile $env:TEMP\PC-Companion.ps1; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
 echo Could not download the PC Hub companion. Check your internet connection.
 pause
 exit /b 1
)
for /f %%T in ('powershell.exe -NoProfile -Command "[guid]::NewGuid().ToString() + [guid]::NewGuid().ToString()"') do set "PCH_TOKEN=%%T"
if not defined PCH_TOKEN (
 echo Could not create the temporary scanner token.
 pause
 exit /b 1
)
start "PC Hub Companion" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PCH_SCRIPT%" -Token "%PCH_TOKEN%"
echo Waiting for the local scanner...
for /l %%i in (1,1,20) do (
 powershell.exe -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8765/api/health' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
 if not errorlevel 1 goto ready
 timeout /t 1 /nobreak >nul
)
echo Scanner did not start. Check whether port 8765 is already in use.
pause
exit /b 1
:ready
echo.
echo PC Hub scanner is running.
echo Return to the PC Hub tab that was already open.
echo It will detect the scanner and start scanning automatically.
echo Keep this window open while using the scanner.
echo.
pause
