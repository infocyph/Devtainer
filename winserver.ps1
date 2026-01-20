$ErrorActionPreference = "Stop"

function Escape-BashArg([string]$s) {
    "'" + ($s -replace "'", "'\"'\"'") + "'"
}

$devHomeWin = $PSScriptRoot
$cwdWin     = (Get-Location).Path

$devHomeWsl = (wsl.exe wslpath -a -u $devHomeWin).Trim()
$cwdWsl     = (wsl.exe wslpath -a -u $cwdWin).Trim()

$argStr = ($args | ForEach-Object { Escape-BashArg $_ }) -join ' '

    # - Always run the real bash script from devtainer home
    # - Pass caller dir as WORKDIR so bash can "act on where command was run"
    $cmd = @"
export WORKDIR=$(Escape-BashArg $cwdWsl)
cd $(Escape-BashArg $devHomeWsl)
chmod +x ./server >/dev/null 2>&1 || true
exec ./server $argStr
"@

    wsl.exe bash -lc $cmd
    exit $LASTEXITCODE
