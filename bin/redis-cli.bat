@echo off
setlocal EnableDelayedExpansion

rem —— Configuration ——
set "SERVICE_NAME=REDIS"
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

rem —— 3) Call the “function” ——
call :redis_cli %*
goto :EOF


:redis_cli
  rem —— a) Verify container running ——
  docker ps --format "{{.Names}}" | findstr /ix "%SERVICE_NAME%" >nul 2>&1
  if errorlevel 1 (
    echo Error: container "%SERVICE_NAME%" is not running.
    endlocal & exit /b 1
  )

  rem —— b) Build redis-cli args ——
  set "ARGS="
  if "%LOGIN_FLAG%"=="true" (
    set "ARGS=-h 127.0.0.1"
    if defined REDIS_PORT     set "ARGS=!ARGS! -p %REDIS_PORT%"
    if defined REDIS_PASSWORD set "ARGS=!ARGS! -a %REDIS_PASSWORD%"
    if defined REDIS_DATABASE set "ARGS=!ARGS! -n %REDIS_DATABASE%"
    if not "%*"==""          set "ARGS=!ARGS! %*"
  ) else (
    set "ARGS=%*"
  )

  rem —— c) Exec into the container ——
  docker exec -it "%SERVICE_NAME%" redis-cli !ARGS!
  set "RET=%ERRORLEVEL%"

  rem —— d) Teardown & return code ——
  endlocal & exit /b %RET%
