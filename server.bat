@echo off
setlocal

:: Get the script directory
set "directory=%~dp0"
set "directory=%directory:~0,-1%"

:: Extract the drive and convert path for Git Bash
set "drive=%directory:~0,1%"
set "path_without_drive=%directory:~2%"
set "unix_path=/%drive%/%path_without_drive%"
set "unix_path=%unix_path:\=/%"  :: Convert backslashes to forward slashes

:: Ensure Git Bash is detected
if not defined git_bash_path (
    for /f "delims=" %%i in ('where git') do set "git_path=%%i"
    if "%git_path%"=="" (
        echo "Git is not installed or could not be found. Please install Git for Windows."
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
        echo "Git Bash not found in the expected directories."
        exit /b 1
    )
)

:: Pass all arguments to the Bash script
:run_bash
"%git_bash_path%" -c "export TERM=xterm-256color; cd '%unix_path%' && ./server %*"
endlocal
