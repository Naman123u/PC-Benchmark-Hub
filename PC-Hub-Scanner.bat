@echo off
setlocal
title PC Hub - Hardware Scanner
color 0B
echo.
echo   ================================================
echo        PC HUB - CONNECTED HARDWARE SCANNER
echo   ================================================
echo.
echo Downloading the PC Hub local scanner component...
set "PCH_SCRIPT=%TEMP%\PC-Companion.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Naman123u/PC-Benchmark-Hub/main/PC-Companion.ps1' -OutFile $env:TEMP\PC-Companion.ps1; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
  echo ERROR: Could not download the PC Hub companion. Check your internet connection.
  pause
  exit /b 1
)
for /f %%T in ('powershell.exe -NoProfile -Command "[guid]::NewGuid().ToString() + [guid]::NewGuid().ToString()"') do set "PCH_TOKEN=%%T"
if not defined PCH_TOKEN (
  echo ERROR: Could not create a temporary connection token.
  pause
  exit /b 1
)
start "PC Hub Companion" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PCH_SCRIPT%" -Token "%PCH_TOKEN%"
echo Starting local hardware detection...
for /l %%i in (1,1,20) do (
  powershell.exe -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8765/api/health' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto ready
  timeout /t 1 /nobreak >nul
)
echo ERROR: The PC Hub companion did not start.
echo Check whether port 8765 is already in use.
pause
exit /b 1
:ready
echo Scanner connected. Opening PC Hub...
start "" "https://naman123u.github.io/PC-Benchmark-Hub/my-pc.html?bridgeToken=%PCH_TOKEN%&scan=1"
echo.
echo Keep this window open while using PC Hub.
echo Close it when you finish. You can also use Disconnect on the website.
pause
