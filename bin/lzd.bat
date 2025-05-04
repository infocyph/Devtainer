@echo off
setlocal

set "SERVICE=SERVER_TOOLS"

rem verify container is running
docker ps --format "{{.Names}}" | findstr /ix "%SERVICE%" >nul 2>&1
if errorlevel 1 (
  echo Error: container "%SERVICE%" is not running.
  endlocal & exit /b 1
)

rem exec lazydocker
docker exec -it "%SERVICE%" lazydocker
endlocal
