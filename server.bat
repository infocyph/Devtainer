@echo off
setlocal
if not "%git_bash_path%"=="" (
    goto run_bash
)
set "git_path="
for /f "delims=" %%i in ('where git') do set "git_path=%%i"
if "%git_path%"=="" (
    for /f "delims=" %%i in ('where.exe git') do set "git_path=%%i"
)
if "%git_path%"=="" (
    echo "Git is not installed or could not be found. Please install Git for Windows from: https://git-scm.com/"
    exit /b 1
)

set "git_install_dir=%git_path%\..\.."
if exist "%git_install_dir%\bin\bash.exe" (
    set "git_bash_path=%git_install_dir%\bin\bash.exe"
) else if exist "%git_install_dir%\usr\bin\bash.exe" (
    set "git_bash_path=%git_install_dir%\usr\bin\bash.exe"
) else if exist "%git_install_dir%\mingw64\bin\bash.exe" (
    set "git_bash_path=%git_install_dir%\mingw64\bin\bash.exe"
) else (
    echo "Git Bash not found in the expected directories. Make sure your Git installation is up-to-date & includes Bash."
    exit /b 1
)
setx git_bash_path "%git_bash_path%"
set "directory=%~dp0"
set "directory=%directory:~0,-1%"
setx directory "%directory%"

:run_bash
"%git_bash_path%" "%directory%\server" %*
endlocal
