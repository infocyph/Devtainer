@echo off
setlocal EnableExtensions

set "PS_SCRIPT=%~dp0server.ps1"
if not exist "%PS_SCRIPT%" exit /b 1

where /q pwsh.exe
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b %errorlevel%
)

where /q powershell.exe
if %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
  exit /b %errorlevel%
)

exit /b 1
