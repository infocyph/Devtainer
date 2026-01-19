@echo off
setlocal EnableExtensions

set "PS_SCRIPT=%~dp0winserver.ps1"
if not exist "%PS_SCRIPT%" (
  echo [winserver] ERROR: winserver.ps1 not found: "%PS_SCRIPT%"
  exit /b 1
)

where /q pwsh.exe
if %errorlevel%==0 (
  pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b %errorlevel%
)

where /q powershell.exe
if %errorlevel%==0 (
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b %errorlevel%
)

echo [winserver] ERROR: PowerShell not found in PATH.
exit /b 1
