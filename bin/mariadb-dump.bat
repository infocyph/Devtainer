@echo off
setlocal EnableDelayedExpansion

rem —— Configuration ——
set "SERVICE_NAME=MARIADB"
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

rem —— 3) Call the “function” and quit ——
call :mariadb_dump %*
goto :EOF



:mariadb_dump
  rem —— 3a) Check container running ——
  docker ps --format "{{.Names}}" | findstr /ix "%SERVICE_NAME%" >nul 2>&1
  if errorlevel 1 (
    echo Error: container "%SERVICE_NAME%" is not running.
    endlocal & exit /b 1
  )

  rem —— 3b) Build dump arguments ——
  set "ARGS="
  if "%LOGIN_FLAG%"=="true" (
    set "ARGS=-h127.0.0.1 -P%MARIADB_PORT% -u%MARIADB_USER% -p%MARIADB_PASSWORD%"
    if defined MARIADB_DATABASE (
      set "ARGS=!ARGS! %MARIADB_DATABASE%"
    )
    if not "%*"=="" (
      set "ARGS=!ARGS! %*"
    )
  ) else (
    set "ARGS=%*"
  )

  rem —— 3c) Exec the dump ——
  docker exec -i "%SERVICE_NAME%" mariadb-dump !ARGS!
  set "RET=%ERRORLEVEL%"

  rem —— 3d) Tear down and return code ——
  endlocal & exit /b %RET%

