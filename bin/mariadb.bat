@echo off
setlocal EnableDelayedExpansion

rem —— Configuration ——
set "SERVICE_NAME=MARIADB"
set "LOGIN_FLAG=false"

rem —— Locate .env ——
set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%..\docker\.env"

if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1* delims==" %%A in (`
    type "%ENV_FILE%" ^| findstr /v /b "#" ^| findstr /v /b "UID="
  `) do (
    set "%%A=%%B"
  )
) else (
  echo Warning: .env file not found at "%ENV_FILE%"
)

rem —— Check for --login switch ——
if /i "%~1"=="--login" (
  set "LOGIN_FLAG=true"
  shift
)

rem —— Verify container is running ——
docker ps --format "{{.Names}}" | findstr /ix "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
  echo Error: container "%SERVICE_NAME%" is not running.
  endlocal & exit /b 1
)

rem —— Build mariadb-client args ——
set "ARGS="
if "%LOGIN_FLAG%"=="true" (
  rem use credentials from .env
  set "ARGS=-h127.0.0.1 -P%MARIADB_PORT% -u%MARIADB_USER% -p%MARIADB_PASSWORD%"
  if defined MARIADB_DATABASE (
    set "ARGS=!ARGS! %MARIADB_DATABASE%"
  )
  if not "%*"=="" (
    set "ARGS=!ARGS! %*"
  )
) else (
  rem pass through whatever was given
  set "ARGS=%*"
)

rem —— Exec into the container ——
docker exec -it "%SERVICE_NAME%" mariadb %ARGS%
set "EXITCODE=%ERRORLEVEL%"

endlocal & exit /b %EXITCODE%
