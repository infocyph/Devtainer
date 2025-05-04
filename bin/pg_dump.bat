@echo off
setlocal EnableDelayedExpansion

set "SERVICE=POSTGRESQL"
set "LOGIN=false"

rem — load .env (skip UID) —
set "DIR=%~dp0"
set "ENV=%DIR%..\docker\.env"
if exist "%ENV%" (
  for /f "usebackq tokens=1* delims==" %%A in (`
    type "%ENV%" ^| findstr /v /b "#" ^| findstr /v /b "UID="
  `) do set "%%A=%%B"
) else (
  echo Warning: .env file not found at "%ENV%"
)

rem — detect --login —
if /i "%~1"=="--login" set "LOGIN=true" & shift

goto :run_pg_dump

:run_pg_dump
  docker ps --format "{{.Names}}" | findstr /ix "%SERVICE%" >nul 2>&1
  if errorlevel 1 (
    echo Error: "%SERVICE%" not running.
    endlocal & exit /b 1
  )

  set "ARGS="
  if "%LOGIN%"=="true" (
    set "ARGS=-h127.0.0.1 -p%POSTGRESQL_PORT% -U%POSTGRESQL_USER%"
    if defined POSTGRESQL_DATABASE set "ARGS=!ARGS! -d %POSTGRESQL_DATABASE%"
    if not "%*"=="" set "ARGS=!ARGS! %*"
  ) else (
    set "ARGS=%*"
  )

  docker exec -i -e PGPASSWORD=%POSTGRESQL_PASSWORD% "%SERVICE%" pg_dump !ARGS!
  set "RC=%ERRORLEVEL%"
  endlocal & exit /b %RC%
