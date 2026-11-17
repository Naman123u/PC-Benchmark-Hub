@echo off
setlocal
title PC Hub - Start local companion
color 0B
echo.
echo   ================================================
echo        PC HUB 3.0 - LOCAL PC SCANNER
echo   ================================================
echo.
echo This scanner reads basic hardware details only.
echo It does not create a report file or upload your specs.
echo A temporary connection is opened for this browser tab.
echo.
rem Close the previous companion process recorded by this scanner.
powershell.exe -NoProfile -Command "$f=Join-Path $env:TEMP 'PCHubCompanion.pid'; if (Test-Path $f) { $id=[int](Get-Content $f); $p=Get-CimInstance Win32_Process -Filter ('ProcessId='+$id); if ($p -and $p.CommandLine -like '*PC-Companion.ps1*') { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }; Remove-Item $f -Force -ErrorAction SilentlyContinue }" >nul 2>nul
timeout /t 1 /nobreak >nul
for /f %%T in ('powershell.exe -NoProfile -Command "[guid]::NewGuid().ToString() + [guid]::NewGuid().ToString()"') do set "PCH_TOKEN=%%T"
if not defined PCH_TOKEN (
  echo Could not create a temporary security token.
  pause
  exit /b 1
)
start "PC Hub Companion" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PC-Companion.ps1" -Token "%PCH_TOKEN%"
echo Starting the local companion...
for /l %%i in (1,1,20) do (
  powershell.exe -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8765/api/health' -TimeoutSec 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto ready
  timeout /t 1 /nobreak >nul
)
echo.
echo ERROR: The local companion did not start.
echo Check whether another PC Hub companion is already running on port 8765.
echo You can close old PowerShell processes named PC-Companion.ps1 in Task Manager.
pause
exit /b 1
:ready
echo.
echo Companion ready. Opening the Game Finder and scanning your PC...
start "" "https://naman123u.github.io/PC-Benchmark-Hub/games.html?bridgeToken=%PCH_TOKEN%&scan=1"
echo.
echo Leave the companion running while using PC Hub.
echo To stop it, open My PC on the website and click Disconnect companion.
echo.
pause
