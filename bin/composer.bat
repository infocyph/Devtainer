@echo off
setlocal EnableDelayedExpansion

rem ────────────────────────────────────────────────────────────────
rem 1) Parse -V <version>
rem ────────────────────────────────────────────────────────────────
set "TARGET="
if /i "%~1"=="-V" (
  if "%~2"=="" (
    echo Error: -V requires a version (e.g. -V 8.3)
    exit /b 1
  )
  set "TARGET=PHP_%~2"
  shift & shift
)

rem ────────────────────────────────────────────────────────────────
rem 2) Auto-detect highest if none specified
rem ────────────────────────────────────────────────────────────────
if "%TARGET%"=="" (
  for %%V in (8.4 8.3 8.2 8.1 8.0 7.4 7.3) do (
    docker ps --format "{{.Names}}" | findstr /ix "PHP_%%V" >nul 2>&1
    if not errorlevel 1 (
      set "TARGET=PHP_%%V"
      goto :FOUND
    )
  )
)
:FOUND
if "%TARGET%"=="" (
  echo Error: no PHP container (PHP_8.4 … PHP_7.3) is running.
  exit /b 1
)

rem ────────────────────────────────────────────────────────────────
rem 3) Lookup the image
rem ────────────────────────────────────────────────────────────────
for /f "delims=" %%I in ('
  docker inspect -f "{{.Config.Image}}" "%TARGET%"
') do set "IMAGE=%%I"

rem ────────────────────────────────────────────────────────────────
rem 4) Build docker run flags
rem ────────────────────────────────────────────────────────────────
set "FLAGS=--rm -v "%cd%":/workspace -w /workspace -it"

rem ────────────────────────────────────────────────────────────────
rem 5) Run php with remaining args
rem ────────────────────────────────────────────────────────────────
docker run %FLAGS% "%IMAGE%" composer %*
endlocal & exit /b %ERRORLEVEL%
