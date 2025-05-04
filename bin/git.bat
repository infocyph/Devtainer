@echo off
setlocal EnableDelayedExpansion

rem —— Configuration ——
set "SERVICE=SERVER_TOOLS"

rem —— 1) Verify the container is running ——
docker ps --format "{{.Names}}" | findstr /ix "%SERVICE%" >nul 2>&1
if errorlevel 1 (
  echo Error: container "%SERVICE%" is not running.
  endlocal & exit /b 1
)

rem —— 2) Determine the image backing that container ——
for /f "delims=" %%I in ('
  docker inspect -f "{{.Config.Image}}" "%SERVICE%"
') do set "IMAGE=%%I"

rem —— 3) Paths for SSH and Git config ——
set "SSH_DIR=%USERPROFILE%\.ssh"
set "GITCONF=%USERPROFILE%\.gitconfig"

if not exist "%SSH_DIR%" (
  echo Warning: SSH directory "%SSH_DIR%" not found.
)
if not exist "%GITCONF%" (
  echo Warning: Git config "%GITCONF%" not found.
)

rem —— 4) Run an ephemeral container with only SSH, .gitconfig and cwd mounted ——
docker run --rm -it ^
  -e HOME=/root ^
  -v "%SSH_DIR%:/root/.ssh:ro" ^
  -v "%GITCONF%:/root/.gitconfig:ro" ^
  -v "%CD%:/app" ^
  -w /app ^
  "%IMAGE%" git %*

endlocal
