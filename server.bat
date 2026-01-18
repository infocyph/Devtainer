@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PS_SCRIPT=%~dp0server.ps1"
if not exist "%PS_SCRIPT%" (
  echo [server] ERROR: server.ps1 not found: "%PS_SCRIPT%"
  exit /b 1
)

where /q pwsh.exe
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b !errorlevel!
)

where /q powershell.exe
if %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b !errorlevel!
)

echo [server] ERROR: PowerShell not found in PATH. Install PowerShell (pwsh) or enable Windows PowerShell.
exit /b 1
