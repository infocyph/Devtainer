@echo off
setlocal

REM Devtainer home = folder where this .bat lives
set "DEVHOME=%~dp0"
REM Remove trailing backslash
if "%DEVHOME:~-1%"=="\" set "DEVHOME=%DEVHOME:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%DEVHOME%\winserver.ps1" %*
exit /b %ERRORLEVEL%
