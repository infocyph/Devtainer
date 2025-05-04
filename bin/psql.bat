@echo off
setlocal EnableDelayedExpansion

rem —— Configuration ——
set "SERVICE_NAME=POSTGRESQL"
set "LOGIN_FLAG=false"

rem —— 1) Load docker\.env (skip UID) ——
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

rem —— 2) Detect --login switch ——
if /i "%~1"=="--login" (
  set "LOGIN_FLAG=true"
  shift
)

rem —— 3) Invoke the “function” ——
call :psql_cmd %*
goto :EOF


:psql_cmd
  rem —— 3a) Verify container is running ——
  docker ps --format "{{.Names}}" | findstr /ix "%SERVICE_NAME%" >nul 2>&1
  if errorlevel 1 (
    echo Error: container "%SERVICE_NAME%" is not running.
    endlocal & exit /b 1
  )

  rem —— 3b) Build psql-client args ——
  set "ARGS="
  if "%LOGIN_FLAG%"=="true" (
    set "ARGS=-h127.0.0.1 -p%POSTGRESQL_PORT% -U%POSTGRESQL_USER%"
    if defined POSTGRESQL_DATABASE (
      set "ARGS=!ARGS! -d %POSTGRESQL_DATABASE%"
    )
    if not "%*"=="" (
      set "ARGS=!ARGS! %*"
    )
  ) else (
    set "ARGS=%*"
  )

  rem —— 3c) Exec into the container ——
  docker exec -it -e PGPASSWORD=%POSTGRESQL_PASSWORD% "%SERVICE_NAME%" psql !ARGS!
  set "RET=%ERRORLEVEL%"

  rem —— 3d) Teardown & return code ——
  endlocal & exit /b %RET%
