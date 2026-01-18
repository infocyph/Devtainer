#!/usr/bin/env pwsh
<#!
server.ps1 – Devtainer CLI launcher (PowerShell port)
Usage:
pwsh -ExecutionPolicy Bypass -File ./server.ps1 help
pwsh -ExecutionPolicy Bypass -File ./server.ps1 start
pwsh -ExecutionPolicy Bypass -File ./server.ps1 -v rebuild all
!>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

###############################################################################
# 0. PATHS & CONSTANTS
###############################################################################
$ScriptPath = $MyInvocation.MyCommand.Path
$DIR = Split-Path -Parent (Resolve-Path -LiteralPath $ScriptPath)

$CFG = Join-Path $DIR 'docker'
$ENV_MAIN = Join-Path $DIR '.env'
$ENV_DOCKER = Join-Path $CFG '.env'
$COMPOSE_FILE = Join-Path $CFG 'compose/main.yaml'

function Ansi([string]$code)
{
    "`e[$code" + "m"
}
$script:RED = Ansi '0;31'
$script:GREEN = Ansi '0;32'
$script:CYAN = Ansi '0;36'
$script:YELLOW = Ansi '1;33'
$script:BLUE = Ansi '0;34'
$script:MAGENTA = Ansi '0;35'
$script:WHITE = Ansi '0;37'
$script:NC = Ansi '0'

# Default behavior: QUIET
$script:VERBOSE = $false

###############################################################################
# 0. GLOBAL ERROR HANDLER
###############################################################################
function Die([string]$Message)
{
    throw $Message
}

###############################################################################
# 1. COMMON HELPERS
###############################################################################
function Need([string[]]$Groups)
{
    foreach ($group in $Groups)
    {
        $alts = $group -split '[|,]'
        $found = $false
        foreach ($cmd in $alts)
        {
            if (Get-Command $cmd -ErrorAction SilentlyContinue)
            {
                $found = $true; break
            }
        }
        if (-not $found)
        {
            $miss = ($alts -join ' or ')
            Die "Missing command(s): $miss"
        }
    }
}

function LogV([string]$Tag, [string]$Msg)
{
    if ($script:VERBOSE)
    {
        [Console]::Error.WriteLine("$( $script:CYAN )[$Tag]$( $script:NC ) $Msg")
    }
}
function LogQ([string]$Tag, [string]$Msg)
{
    [Console]::Error.WriteLine("$( $script:CYAN )[$Tag]$( $script:NC ) $Msg")
}

function Ensure-FilesExist([string[]]$RelPaths)
{
    foreach ($rel in $RelPaths)
    {
        $r = $rel.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
        $abs = Join-Path $DIR $r
        $d = Split-Path -Parent $abs

        if (-not (Test-Path -LiteralPath $d))
        {
            try
            {
                New-Item -ItemType Directory -Path $d -Force | Out-Null
                Write-Host "$( $script:YELLOW )- Created directory $d$( $script:NC )"
            }
            catch
            {
                Write-Host "$( $script:YELLOW )- Warning:$( $script:NC ) cannot create directory $d (permissions?)"
                continue
            }
        }
        elseif (-not (Test-Path -LiteralPath $d -PathType Container))
        {
            Write-Host "$( $script:YELLOW )- Warning:$( $script:NC ) not a directory: $d"
            continue
        }

        if (Test-Path -LiteralPath $abs)
        {
            try
            {
                $null = [IO.File]::Open($abs, 'Open', 'ReadWrite', 'ReadWrite');$null.Close()
            }
            catch
            {
                Write-Host "$( $script:YELLOW )- Warning:$( $script:NC ) file not writable: $abs"
            }
        }
        else
        {
            try
            {
                New-Item -ItemType File -Path $abs -Force | Out-Null
                Write-Host "$( $script:YELLOW )- Created file $abs$( $script:NC )"
            }
            catch
            {
                Write-Host "$( $script:RED )- Error:$( $script:NC ) cannot create file $abs (permissions?)"
            }
        }
    }
}

function Update-Env([string]$File, [string]$Var, [string]$Val)
{
    $parent = Split-Path -Parent $File
    if (-not (Test-Path -LiteralPath $parent))
    {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $File))
    {
        Write-Host "$( $script:YELLOW )File '$File' not found. Creating one.$( $script:NC )"
        New-Item -ItemType File -Path $File -Force | Out-Null
    }

    $lines = @(Get-Content -LiteralPath $File -ErrorAction SilentlyContinue)
    if ($null -eq $lines)
    {
        $lines = @()
    }

    $escaped = [Regex]::Escape($Var)
    $rx = "^[# ]*${escaped}="

    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $rx)
        {
            $lines[$i] = "$Var=$Val"
            $updated = $true
            break
        }
    }
    if (-not $updated)
    {
        $lines += "$Var=$Val"
    }

    $tmp = "$File.tmp"
    Set-Content -LiteralPath $tmp -Value $lines -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $File -Force
}

###############################################################################
# Docker compose wrapper (quiet by default)
###############################################################################
function Docker-Compose
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & docker compose --project-directory $DIR -f $COMPOSE_FILE --env-file $ENV_DOCKER @Args
}

function Dc-Up
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE)
    {
        Docker-Compose @Args
    }
    else
    {
        Docker-Compose up --quiet-pull @Args
    }
}
function Dc-Pull
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE)
    {
        Docker-Compose pull @Args
    }
    else
    {
        Docker-Compose pull -q @Args
    }
}
function Dc-Build
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE)
    {
        Docker-Compose build @Args
    }
    else
    {
        Docker-Compose build --quiet @Args
    }
}

function Http-Reload
{
    Write-Host "$( $script:GREEN )Reloading HTTP…$( $script:NC )"
    try
    {
        $ng = (& docker ps -qf name=NGINX 2> $null)
        if ($ng)
        {
            & docker exec NGINX nginx -s reload 2> $null | Out-Null
        }
    }
    catch
    {
    }
    try
    {
        $ap = (& docker ps -qf name=APACHE 2> $null)
        if ($ap)
        {
            & docker exec APACHE apachectl graceful 2> $null | Out-Null
        }
    }
    catch
    {
    }
    Write-Host "$( $script:GREEN )HTTP reloaded$( $script:NC )"
}

###############################################################################
# 2. PERMISSIONS FIX-UP
###############################################################################
function Is-WindowsLike
{
    return $IsWindows
}

function Get-Euid
{
    if (Get-Command id -ErrorAction SilentlyContinue)
    {
        $u = & id -u 2> $null
        if ($LASTEXITCODE -eq 0 -and $u)
        {
            return [int]$u.Trim()
        }
    }
    return -1
}

function Fix-Perms
{
    # Windows: behave like Linux "install" (make `server` runnable from anywhere)
    # - Create a shim: %USERPROFILE%\bin\server.cmd -> calls <root>\server.bat
    # - Ensure PATH contains: %USERPROFILE%\bin and <root>\bin (User PATH)
    if (Is-WindowsLike)
    {
        $root = $DIR
        $userHome = $env:USERPROFILE
        if ([string]::IsNullOrWhiteSpace($userHome))
        {
            Die 'USERPROFILE is not set.'
        }

        $userBin = Join-Path $userHome 'bin'
        $projBin = Join-Path $root 'bin'

        $targetBat = Join-Path $root 'server.bat'
        if (-not (Test-Path -LiteralPath $targetBat))
        {
            Die "server.bat not found at: $targetBat"
        }

        if (-not (Test-Path -LiteralPath $userBin))
        {
            New-Item -ItemType Directory -Path $userBin -Force | Out-Null
        }

        # Create/overwrite shim (ASCII is safest for .cmd)
        $shim = Join-Path $userBin 'server.cmd'
        $shimBody = "@echo off`r`ncall `"$targetBat`" %*`r`n"
        Set-Content -LiteralPath $shim -Value $shimBody -Encoding Ascii

        function Normalize-Path([string]$p)
        {
            if ([string]::IsNullOrWhiteSpace($p)) { return '' }
            $x = $p.Trim()
            while ($x.EndsWith('\') -or $x.EndsWith('/'))
            {
                $x = $x.Substring(0, $x.Length - 1)
            }
            return $x.ToLowerInvariant()
        }

        # Update User PATH (HKCU) and current process PATH
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($null -eq $userPath) { $userPath = '' }

        $parts = @()
        foreach ($pp in ($userPath -split ';'))
        {
            $t = $pp.Trim()
            if ($t) { $parts += $t }
        }

        $need = @($userBin, $projBin)
        $changed = $false

        foreach ($add in $need)
        {
            $nAdd = Normalize-Path $add

            $exists = $false
            foreach ($pp in $parts)
            {
                if ((Normalize-Path $pp) -eq $nAdd) { $exists = $true; break }
            }

            if (-not $exists)
            {
                $parts += $add
                $changed = $true
            }

            # apply to current session for immediate usability
            $envExists = $false
            foreach ($ep in ($env:Path -split ';'))
            {
                if ((Normalize-Path $ep) -eq $nAdd) { $envExists = $true; break }
            }
            if (-not $envExists)
            {
                $env:Path = ($env:Path.TrimEnd(';') + ';' + $add)
            }
        }

        if ($changed)
        {
            [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
        }

        Write-Host "$( $script:GREEN )Installed Windows shims + PATH.$( $script:NC )"
        Write-Host "  shim : $shim"
        Write-Host "  PATH+: $userBin"
        Write-Host "  PATH+: $projBin"
        Write-Host "$( $script:YELLOW )Open a NEW terminal to pick up User PATH changes system-wide.$( $script:NC )"
        return
    }
}


###############################################################################
# 3. DOMAIN & PROFILE UTILITIES
###############################################################################
function MkHost
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & docker exec SERVER_TOOLS mkhost @Args
}

function Modify-Profiles
{
    param(
        [ValidateSet('add', 'remove')][string]$Action,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Profiles
    )

    $file = $ENV_DOCKER
    $var = 'COMPOSE_PROFILES'

    $existing = @()
    if (Test-Path -LiteralPath $file)
    {
        $line = (Select-String -LiteralPath $file -Pattern "^\s*${var}=" -ErrorAction SilentlyContinue | Select-Object -Last 1)
        if ($line)
        {
            $value = ($line.Line -split '=', 2)[1]
            if ($value)
            {
                $existing = $value.Split(',', [StringSplitOptions]::RemoveEmptyEntries)
            }
        }
    }

    $updated = New-Object System.Collections.Generic.List[string]
    switch ($Action)
    {
        'add' {
            foreach ($p in $Profiles)
            {
                if ( [string]::IsNullOrWhiteSpace($p))
                {
                    continue
                }
                if (-not ($existing -contains $p) -and -not ($updated -contains $p))
                {
                    [void]$updated.Add($p)
                }
            }
            foreach ($e in $existing)
            {
                if (-not ($updated -contains $e))
                {
                    [void]$updated.Add($e)
                }
            }
        }
        'remove' {
            foreach ($e in $existing)
            {
                if (-not ($Profiles -contains $e))
                {
                    [void]$updated.Add($e)
                }
            }
        }
    }

    $val = ($updated.ToArray() -join ',')
    Update-Env $file $var $val
}

function Setup-Domain
{
    MkHost --RESET | Out-Null
    & docker exec -it SERVER_TOOLS mkhost

    $phpProf = $null
    $svrProf = $null
    try
    {
        $phpProf = (MkHost --ACTIVE_PHP_PROFILE 2> $null)
    }
    catch
    {
    }
    try
    {
        $svrProf = (MkHost --APACHE_ACTIVE 2> $null)
    }
    catch
    {
    }

    $phpProf = ($phpProf | Out-String).Trim()
    $svrProf = ($svrProf | Out-String).Trim()

    if ($phpProf)
    {
        Modify-Profiles add $phpProf
    }
    if ($svrProf)
    {
        Modify-Profiles add $svrProf
    }

    MkHost --RESET | Out-Null
    Http-Reload
}

###############################################################################
# setup profiles parity with docker/utilities/profiles (bash)
###############################################################################
# SERVICE -> profile (single profile per service)
$script:SERVICES = [ordered]@{
    'ELASTICSEARCH' = 'elasticsearch'
    'MYSQL' = 'mysql'
    'MARIADB' = 'mariadb'
    'MONGODB' = 'mongodb'
    'REDIS' = 'redis'
    'POSTGRESQL' = 'postgresql'
}

# PROFILE -> KEY=DEFAULT entries (space separated like bash)
$script:PROFILE_ENV = @{
    'elasticsearch' = 'ELASTICSEARCH_VERSION=8.18.0 ELASTICSEARCH_PORT=9200'
    'mysql' = 'MYSQL_VERSION=latest MYSQL_PORT=3306 MYSQL_ROOT_PASSWORD=12345 MYSQL_USER=infocyph MYSQL_PASSWORD=12345 MYSQL_DATABASE=localdb'
    'mariadb' = 'MARIADB_VERSION=latest MARIADB_PORT=3306 MARIADB_ROOT_PASSWORD=12345 MARIADB_USER=infocyph MARIADB_PASSWORD=12345 MARIADB_DATABASE=localdb'
    'mongodb' = 'MONGODB_VERSION=latest MONGODB_PORT=27017 MONGODB_ROOT_USERNAME=root MONGODB_ROOT_PASSWORD=12345'
    'redis' = 'REDIS_VERSION=latest REDIS_PORT=6379'
    'postgresql' = 'POSTGRES_VERSION=latest POSTGRES_PORT=5432 POSTGRES_USER=postgres POSTGRES_PASSWORD=postgres POSTGRES_DATABASE=postgres'
}

$script:PENDING_ENVS = New-Object System.Collections.Generic.List[string]
$script:PENDING_PROFILES = New-Object System.Collections.Generic.List[string]

function Queue-Env([string]$kv)
{
    [void]$script:PENDING_ENVS.Add($kv)
}
function Queue-Profile([string]$p)
{
    [void]$script:PENDING_PROFILES.Add($p)
}

function Read-Default([string]$Prompt, [string]$Default)
{
    $in = Read-Host "$( $script:CYAN )$Prompt [default: $Default]: $( $script:NC )"
    if ( [string]::IsNullOrWhiteSpace($in))
    {
        return $Default
    }
    return $in
}

function Ask-Yes([string]$Prompt)
{
    $ans = Read-Host "$( $script:BLUE )$Prompt (y/n): $( $script:NC )"
    return (($ans ?? '').Trim().ToLowerInvariant() -eq 'y')
}

function Flush-Envs
{
    $envFile = Join-Path $DIR 'docker/.env'
    foreach ($kv in $script:PENDING_ENVS)
    {
        $parts = $kv -split '=', 2
        if ($parts.Count -ne 2)
        {
            continue
        }
        Update-Env $envFile $parts[0] $parts[1]
    }
}

function Flush-Profiles
{
    foreach ($p in $script:PENDING_PROFILES)
    {
        Modify-Profiles add $p
    }
}

function Process-Service([string]$ServiceKey)
{
    Write-Host "`n$( $script:YELLOW )→ $ServiceKey$( $script:NC )"

    if (-not (Ask-Yes "Enable $ServiceKey?"))
    {
        Write-Host "$( $script:RED )Skipping $ServiceKey$( $script:NC )"
        return
    }

    $profile = $script:SERVICES[$ServiceKey]
    if (-not $profile)
    {
        return
    }

    Queue-Profile $profile
    Write-Host "$($script: BLUE)Enter value(s) for $ServiceKey: $($script: NC)"

    $pairs = ($script:PROFILE_ENV[$profile] ?? '')
    if (-not $pairs) {
    return
    }

    foreach ($pair in ($pairs -split '\s+')) {
    if (-not $pair) {
    continue
    }
    $kv = $pair -split '=', 2
    if ($kv.Count -ne 2) {
    continue
    }
    $key = $kv[0]
    $def = $kv[1]
    $val = Read-Default $key $def
    Queue-Env "$key=$val"
    }
}

function Process-All
{
    # mirrors bash: for svc in "${!SERVICES[@]}"; do process_service; done
    foreach ($svc in $script:SERVICES.Keys)
    {
        Process-Service $svc
    }
    Flush-Envs
    Flush-Profiles
    Write-Host "`n$( $script:GREEN )✅ All services configured!$( $script:NC )"
}

###############################################################################
# 4. LAUNCH PHP CONTAINER INSIDE DOCROOT
###############################################################################
function Launch-PHP([string]$Domain)
{
    if ( [string]::IsNullOrWhiteSpace($Domain))
    {
        Die "Usage: server core <domain>"
    }

    $nconf = Join-Path $DIR ("configuration/nginx/{0}.conf" -f $Domain)
    $aconf = Join-Path $DIR ("configuration/apache/{0}.conf" -f $Domain)

    if (-not (Test-Path -LiteralPath $nconf))
    {
        Die "No Nginx config for $Domain"
    }

    $docroot = $null
    $php = $null

    $nLines = Get-Content -LiteralPath $nconf -ErrorAction Stop

    $hasFastcgi = $false
    foreach ($ln in $nLines)
    {
        if ($ln -match 'fastcgi_pass\s+([^:;\s]+):9000')
        {
            $php = $Matches[1].Trim(); $hasFastcgi = $true; break
        }
    }

    if ($hasFastcgi)
    {
        foreach ($ln in $nLines)
        {
            if ($ln -match '^\s*root\s+([^;]+)')
            {
                $docroot = $Matches[1].Trim(); break
            }
        }
    }
    else
    {
        if (-not (Test-Path -LiteralPath $aconf))
        {
            Die "No Apache config for $Domain"
        }
        $aLines = Get-Content -LiteralPath $aconf -ErrorAction Stop
        foreach ($ln in $aLines)
        {
            if ($ln -match '^\s*DocumentRoot\s+(\S+)')
            {
                $docroot = $Matches[1].Trim(); break
            }
        }
        foreach ($ln in $aLines)
        {
            if ($ln -match 'proxy:fcgi://([^:]+):9000')
            {
                $php = $Matches[1].Trim(); break
            }
        }
    }

    if (-not $php)
    {
        Die "Could not detect PHP container for $Domain"
    }
    if (-not $docroot)
    {
        $docroot = '/app'
    }

    foreach ($suffix in @('public', 'dist', 'public_html'))
    {
        if ($docroot -match ([Regex]::Escape("/$suffix") + '$'))
        {
            $docroot = $docroot.Substring(0, $docroot.Length - ("/$suffix").Length)
            break
        }
    }

    $php = ($php -split '\s+' | Where-Object { $_ } | Select-Object -Unique) -join ' '

    & docker exec -it $php bash --login -c "cd '$docroot' && exec bash"
}

###############################################################################
# 5. ENV + CERT
###############################################################################
function Detect-Timezone
{
    if (Get-Command timedatectl -ErrorAction SilentlyContinue)
    {
        $tz = & timedatectl show -p Timezone --value 2> $null
        if ($LASTEXITCODE -eq 0 -and $tz)
        {
            return ($tz | Out-String).Trim()
        }
    }
    if ($env:TZ)
    {
        return $env:TZ
    }
    if (Test-Path -LiteralPath /etc/timezone)
    {
        try
        {
            return (Get-Content -LiteralPath /etc/timezone -ErrorAction Stop | Select-Object -First 1).Trim()
        }
        catch
        {
        }
    }
    if ($IsWindows)
    {
        try
        {
            return (Get-TimeZone).Id
        }
        catch
        {
        }
    }
    return (Get-Date).ToString('zzz')
}

function Get-UserName
{
    if ($env:USER)
    {
        return $env:USER
    }
    if ($env:USERNAME)
    {
        return $env:USERNAME
    }
    try
    {
        return [Environment]::UserName
    }
    catch
    {
    }
    return 'user'
}

function Get-PosixId([ValidateSet('u', 'g')][string]$Which, [string]$User)
{
    if (Get-Command id -ErrorAction SilentlyContinue)
    {
        if ($Which -eq 'u')
        {
            return (& id -u $User 2> $null | Out-String).Trim()
        }
        else
        {
            return (& id -g $User 2> $null | Out-String).Trim()
        }
    }

    if ($IsWindows -and (Get-Command wsl.exe -ErrorAction SilentlyContinue))
    {
        try
        {
            if ($Which -eq 'u')
            {
                return (& wsl.exe -e id -u $User 2> $null | Out-String).Trim()
            }
            else
            {
                return (& wsl.exe -e id -g $User 2> $null | Out-String).Trim()
            }
        }
        catch
        {
        }
    }

    return '1000'
}

function Env-Init
{
    $envFile = Join-Path $DIR 'docker/.env'
    Write-Host "$( $script:YELLOW )Bootstrapping environment defaults…$( $script:NC )"

    $defaultTz = Detect-Timezone
    $tz = Read-Default "Timezone (TZ)" $defaultTz

    $defaultUser = Get-UserName
    $user = Read-Default "User" $defaultUser

    $defaultUid = Get-PosixId u $user
    $defaultGid = Get-PosixId g $user
    $uid = Read-Default "User UID" $defaultUid
    $gid = Read-Default "User GID" $defaultGid

    Update-Env $envFile 'TZ'   $tz
    Update-Env $envFile 'USER' $user
    Update-Env $envFile 'UID'  $uid
    Update-Env $envFile 'GID'  $gid

    Write-Host "$( $script:GREEN )Defaults saved!$( $script:NC )"
}

function Install-CA
{
    $src = Join-Path $DIR 'configuration/rootCA/rootCA.pem'
    if (-not (Test-Path -LiteralPath $src))
    {
        Die "certificate not found: $src"
    }

    if ($IsWindows)
    {
        Write-Host "$( $script:CYAN )Installing root CA (Windows)…$( $script:NC )"
        try
        {
            & certutil.exe -addstore -f Root $src | Out-Null
            Write-Host "$( $script:GREEN )Root CA installed into Windows Root store.$( $script:NC )"
            return
        }
        catch
        {
            Die "Failed to install on Windows. Run elevated PowerShell and ensure certutil exists."
        }
    }

    $euid = Get-Euid
    if ($euid -ne 0)
    {
        Die "install certificate requires sudo (root)"
    }

    $dest = '/usr/local/share/ca-certificates/rootCA.crt'
    Write-Host "$( $script:CYAN )Installing root CA…$( $script:NC )"
    if (Get-Command install -ErrorAction SilentlyContinue)
    {
        & install -m 644 $src $dest | Out-Null
    }
    else
    {
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    if (Get-Command update-ca-certificates -ErrorAction SilentlyContinue)
    {
        & update-ca-certificates | Out-Null
    }
    if (Get-Command trust -ErrorAction SilentlyContinue)
    {
        & trust extract-compat | Out-Null
    }
    Write-Host "$( $script:GREEN )Root CA installed → $dest$( $script:NC )"
}

###############################################################################
# Compose helpers for rebuild
###############################################################################
$script:ComposeConfigLines = $null
function Get-ComposeConfigLines
{
    if ($null -ne $script:ComposeConfigLines)
    {
        return $script:ComposeConfigLines
    }
    $out = & docker compose --project-directory $DIR -f $COMPOSE_FILE --env-file $ENV_DOCKER config 2> $null
    if ($LASTEXITCODE -ne 0 -or -not $out)
    {
        Die 'docker compose config failed. Check compose file / env.'
    }
    $script:ComposeConfigLines = @($out)
    return $script:ComposeConfigLines
}

function Find-ServiceBlock([string]$Service)
{
    $lines = Get-ComposeConfigLines
    $svcLine = "  $Service: "
    $inServices = $false
    $start = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if (-not $inServices)
        {
            if ($line -eq 'services:')
            {
                $inServices = $true
            }
            continue
        }
        if ($start -lt 0)
        {
            if ($line -eq $svcLine)
            {
                $start = $i; continue
            }
            continue
        }
        if ($line -match '^  [A-Za-z0-9_.-]+:$' -and $line -ne $svcLine)
        {
            return @{ Start = $start; End = ($i - 1); Lines = $lines }
        }
    }
    if ($start -ge 0)
    {
        return @{ Start = $start; End = ($lines.Count - 1); Lines = $lines }
    }
    return $null
}

function Compose-HasBuild([string]$Service)
{
    $blk = Find-ServiceBlock $Service
    if (-not $blk)
    {
        return $false
    }
    for ($i = $blk.Start; $i -le $blk.End; $i++) {
        if ($blk.Lines[$i] -match '^    build:')
        {
            return $true
        }
    }
    return $false
}

function Compose-ImageForService([string]$Service)
{
    $blk = Find-ServiceBlock $Service
    if (-not $blk)
    {
        return $null
    }
    for ($i = $blk.Start; $i -le $blk.End; $i++) {
        if ($blk.Lines[$i] -match '^    image:\s*(.+)$')
        {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Normalize-Service([string]$Raw)
{
    if ( [string]::IsNullOrWhiteSpace($Raw))
    {
        return ''
    }
    $s = ($Raw -replace '\s+', '')
    $low = $s.ToLowerInvariant()

    $key = ($low -replace '[_-]', '')
    if ( $key.StartsWith('php'))
    {
        $ver = ($key.Substring(3) -replace '[^0-9]', '')
        if ($ver -match '^([0-9])([0-9])')
        {
            return "php$( $Matches[1] )$( $Matches[2] )"
        }
        return 'php'
    }

    $low = ($low -replace '_', '-')
    while ( $low.Contains('--'))
    {
        $low = $low -replace '--', '-'
    }
    return $low
}

###############################################################################
# 6. COMMANDS
###############################################################################
function Cmd-Up
{
    param([string[]]$Args) Dc-Up @Args
}

function Cmd-Start
{
    param([string[]]$Args)
    Dc-Up -d @Args
    Http-Reload
}
function Cmd-Reload
{
    param([string[]]$Args) Cmd-Start $Args
}

function Cmd-Stop
{
    param([string[]]$Args) Docker-Compose down
}
function Cmd-Down
{
    param([string[]]$Args) Cmd-Stop $Args
}

function Cmd-Restart
{
    param([string[]]$Args)
    Cmd-Stop @()
    Cmd-Start @()
}
function Cmd-Reboot
{
    param([string[]]$Args) Cmd-Restart $Args
}

function Cmd-Rebuild
{
    param([string[]]$Args)
    if (-not $Args -or $Args.Count -lt 1)
    {
        Die "Usage: server rebuild all | server rebuild <service...>"
    }

    $svcs = @()
    if ($Args[0].ToLowerInvariant() -eq 'all')
    {
        $list = Docker-Compose config --services 2> $null
        if ($LASTEXITCODE -ne 0 -or -not $list)
        {
            Die "No services found (docker compose config --services failed?)"
        }
        $svcs = @($list)
    }
    else
    {
        foreach ($a in $Args)
        {
            $svcs += (Normalize-Service $a)
        }
    }

    foreach ($svc in $svcs)
    {
        if ( [string]::IsNullOrWhiteSpace($svc))
        {
            continue
        }

        if (Compose-HasBuild $svc)
        {
            LogQ rebuild "build/recreate $svc"
            Dc-Build --no-cache --pull $svc
            Dc-Up -d --no-deps --force-recreate $svc
            continue
        }

        LogQ rebuild "pull/recreate $svc"

        try
        {
            Docker-Compose rm -sf $svc | Out-Null
        }
        catch
        {
        }

        $img = Compose-ImageForService $svc
        if ($img)
        {
            try
            {
                & docker rmi -f $img 2> $null | Out-Null
            }
            catch
            {
            }
        }

        Dc-Pull $svc
        Dc-Up -d --no-deps --force-recreate $svc
    }
}

function Cmd-Config
{
    param([string[]]$Args) Docker-Compose config
}
function Cmd-Tools
{
    param([string[]]$Args) & docker exec -it SERVER_TOOLS bash
}
function Cmd-Lzd
{
    param([string[]]$Args) & docker exec -it SERVER_TOOLS lazydocker
}
function Cmd-Lazydocker
{
    param([string[]]$Args) Cmd-Lzd $Args
}

function Cmd-Http
{
    param([string[]]$Args)
    if ($Args -and $Args[0].ToLowerInvariant() -eq 'reload')
    {
        Http-Reload; return
    }
    Die "Usage: server http reload"
}

function Cmd-Core
{
    param([string[]]$Args)
    if (-not $Args -or $Args.Count -lt 1)
    {
        Die "Usage: server core <domain>"
    }
    Launch-PHP $Args[0]
}
function Cmd-Cli
{
    param([string[]]$Args) Cmd-Core $Args
}

function Cmd-Setup
{
    param([string[]]$Args)
    $u = Get-UserName
    Update-Env $ENV_DOCKER 'WORKING_DIR' $DIR
    Update-Env $ENV_DOCKER 'USER' $u
    Update-Env $ENV_DOCKER 'UID' (Get-PosixId u $u)
    Update-Env $ENV_DOCKER 'GID' (Get-PosixId g $u)

    $sub = if ($Args -and $Args.Count -gt 0)
    {
        $Args[0].ToLowerInvariant()
    }
    else
    {
        ''
    }
    switch ($sub)
    {
        { $_ -in @('permission', 'permissions', 'perms', 'perm') } {
            Fix-Perms; return
        }
        'domain' {
            Setup-Domain; return
        }
        { $_ -in @('profiles', 'profile') } {
            Process-All; return
        }
        default {
            Die "setup <permissions|domain|profiles>"
        }
    }
}

function Cmd-Env
{
    param([string[]]$Args)
    $sub = if ($Args -and $Args.Count -gt 0)
    {
        $Args[0].ToLowerInvariant()
    }
    else
    {
        ''
    }
    switch ($sub)
    {
        { $_ -in @('init', 'boot') } {
            Env-Init; return
        }
        'edit' {
            Die "ToDo"
        }
        default {
            Die "env <init|edit>"
        }
    }
}

function Cmd-Install
{
    param([string[]]$Args)
    if ($Args.Count -ge 1 -and $Args[0].ToLowerInvariant() -eq 'certificate')
    {
        Install-CA; return
    }
    Die "install certificate"
}

###############################################################################
# NOTIFY
###############################################################################
function Get-NotifySender
{
    if (Get-Command notify-send -ErrorAction SilentlyContinue)
    {
        return 'notify-send'
    }
    return 'fallback'
}

$script:NotifyIcon = $null
function Show-HostNotification([string]$Urgency, [int]$TimeoutMs, [string]$Title, [string]$Body)
{
    $sender = Get-NotifySender
    if ($sender -eq 'notify-send')
    {
        try
        {
            & notify-send -u $Urgency -t $TimeoutMs $Title $Body 2> $null | Out-Null
        }
        catch
        {
        }
        return
    }

    [Console]::Error.WriteLine(("{0} [{1}] {2} - {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Urgency, $Title, $Body))

    if (-not $IsWindows)
    {
        return
    }

    try
    {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        Add-Type -AssemblyName System.Drawing | Out-Null
        if ($null -eq $script:NotifyIcon)
        {
            $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
            $script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
            $script:NotifyIcon.Visible = $true
        }
        $script:NotifyIcon.BalloonTipTitle = $Title
        $script:NotifyIcon.BalloonTipText = $Body
        $script:NotifyIcon.ShowBalloonTip([Math]::Max(1000,[Math]::Min(60000, $TimeoutMs)))
    }
    catch
    {
    }
}

function Notify-Watch([string]$Container = 'SERVER_TOOLS')
{
    $prefix = '__HOST_NOTIFY__'
    Need @('docker')

    $stop = $false
    $handler = {
        $script:stop = $true
        Show-HostNotification 'critical' 2500 'Notifier' 'Notification watcher interrupted/exiting'
        [Console]::Error.WriteLine("$( $script:RED )[watcher]$( $script:NC ) Notification watcher interrupted/exiting")
    }

    $null = Register-EngineEvent -SourceIdentifier ConsoleBreak -Action $handler -ErrorAction SilentlyContinue

    Write-Host "$( $script:GREEN )Notify Watch:$( $script:NC ) monitoring is active. Ctrl+C to stop."

    while (-not $stop)
    {
        $running = $false
        try
        {
            $state = (& docker inspect -f '{{.State.Running}}' $Container 2> $null | Out-String).Trim()
            if ($state -eq 'true')
            {
                $running = $true
            }
        }
        catch
        {
            $running = $false
        }

        if (-not $running)
        {
            Show-HostNotification 'critical' 2500 'Notifier' "Watcher stopped: $Container is not running"
            [Console]::Error.WriteLine("$( $script:RED )[watcher]$( $script:NC ) $Container is not running; exiting.")
            break
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'docker'
        $psi.ArgumentList.Add('logs')
        $psi.ArgumentList.Add('-f')
        $psi.ArgumentList.Add('--tail')
        $psi.ArgumentList.Add('0')
        $psi.ArgumentList.Add($Container)
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $null = $p.Start()

        while (-not $p.HasExited -and -not $stop)
        {
            $line = $p.StandardOutput.ReadLine()
            if ($null -eq $line)
            {
                Start-Sleep -Milliseconds 50; continue
            }

            if ($line -notmatch ("^" + [Regex]::Escape($prefix) + "([\\s]|$)"))
            {
                continue
            }

            $payload = $line.Substring($prefix.Length).TrimStart()
            $parts = $payload -split "`t", 5
            $f1 = if ($parts.Count -ge 1)
            {
                $parts[0]
            }
            else
            {
                ''
            }
            $f2 = if ($parts.Count -ge 2)
            {
                $parts[1]
            }
            else
            {
                ''
            }
            $f3 = if ($parts.Count -ge 3)
            {
                $parts[2]
            }
            else
            {
                ''
            }
            $f4 = if ($parts.Count -ge 4)
            {
                $parts[3]
            }
            else
            {
                ''
            }
            $rest = if ($parts.Count -ge 5)
            {
                $parts[4]
            }
            else
            {
                ''
            }

            $timeout = 2500
            $urgency = 'normal'
            $title = 'Notification'
            $body = ''

            if ($f1 -match '^[0-9]{1,6}$')
            {
                $timeout = [int]$f1
                $urgency = if ($f2)
                {
                    $f2
                }
                else
                {
                    'normal'
                }
                $title = if ($f3)
                {
                    $f3
                }
                else
                {
                    'Notification'
                }
                $body = if ($f4)
                {
                    $f4
                }
                else
                {
                    ''
                }
            }
            else
            {
                $urgency = if ($f1)
                {
                    $f1
                }
                else
                {
                    'normal'
                }
                $title = if ($f2)
                {
                    $f2
                }
                else
                {
                    'Notification'
                }
                $body = if ($f3)
                {
                    $f3
                }
                else
                {
                    ''
                }
            }

            if ($rest)
            {
                $body = $body + "`t" + $rest
            }

            if ($urgency -notin @('low', 'normal', 'critical'))
            {
                $urgency = 'normal'
            }

            Show-HostNotification $urgency $timeout $title $body
        }

        if ($stop)
        {
            try
            {
                if (-not $p.HasExited)
                {
                    $p.Kill()
                }
            }
            catch
            {
            }
            break
        }

        $stillRunning = $false
        try
        {
            $state2 = (& docker inspect -f '{{.State.Running}}' $Container 2> $null | Out-String).Trim()
            if ($state2 -eq 'true')
            {
                $stillRunning = $true
            }
        }
        catch
        {
            $stillRunning = $false
        }

        if ($stillRunning)
        {
            Show-HostNotification 'critical' 2500 'Notifier' 'Watcher lost log stream (docker logs ended). Reconnecting…'
            [Console]::Error.WriteLine("$( $script:YELLOW )[watcher]$( $script:NC ) docker logs ended; reconnecting...")
            Start-Sleep -Seconds 1
            continue
        }

        Show-HostNotification 'critical' 2500 'Notifier' "Watcher stopped: $Container stopped"
        [Console]::Error.WriteLine("$( $script:RED )[watcher]$( $script:NC ) $Container stopped; exiting.")
        break
    }

    try
    {
        Unregister-Event -SourceIdentifier ConsoleBreak -ErrorAction SilentlyContinue | Out-Null
    }
    catch
    {
    }
    if ($stop)
    {
        return 130
    }
    return 0
}

function Notify-Test([string]$Title = 'Notifier OK', [string]$Body = 'Hello from host via SERVER_TOOLS')
{
    & docker exec SERVER_TOOLS notify -t 2500 -u normal $Title $Body
}

function Cmd-Notify
{
    param([string[]]$Args)
    $sub = if ($Args -and $Args.Count -gt 0)
    {
        $Args[0].ToLowerInvariant()
    }
    else
    {
        'watch'
    }
    switch ($sub)
    {
        'watch' {
            $container = if ($Args.Count -ge 2)
            {
                $Args[1]
            }
            else
            {
                'SERVER_TOOLS'
            }
            $code = Notify-Watch $container
            if ($code -ne 0)
            {
                exit $code
            }
            return
        }
        'test' {
            $t = if ($Args.Count -ge 2)
            {
                $Args[1]
            }
            else
            {
                'Notifier OK'
            }
            $b = if ($Args.Count -ge 3)
            {
                $Args[2]
            }
            else
            {
                'Hello from host'
            }
            Notify-Test $t $b
            return
        }
        default {
            Die 'notify <watch [container]|test "Title" "Body">'
        }
    }
}

function Cmd-Help
{
    @"
$( $script:CYAN )Usage:$( $script:NC ) server.ps1 [--verbose|-v] <command> [options]

$( $script:CYAN )Default:$( $script:NC ) quiet docker compose operations. Add $( $script:CYAN )-v$( $script:NC ) / $( $script:CYAN )--verbose$( $script:NC ) to see pull/build progress.

$( $script:CYAN )Core commands:$( $script:NC )
  up / start                 Start docker stack (quiet pull by default)
  stop / down                Stop stack
  reload / restart           Restart stack + reload HTTP
  rebuild all|<svc...>       Rebuild/pull services (no full down)
  config                     Validate compose
  tools                      Enter SERVER_TOOLS container
  lzd | lazydocker           Start LazyDocker
  http reload                Reload Nginx/Apache
  core <domain>              Open bash in PHP container for <domain>

$( $script:CYAN )Setup commands:$( $script:NC )
  setup permissions          Assign/Fix directory/file permissions
  perm / permissions         Same as `setup permissions` (Windows: install shim + PATH)
  setup domain               Setup domain
  setup profiles             Configure DB/cache/search profiles + write docker/.env + COMPOSE_PROFILES

$( $script:CYAN )Env commands:$( $script:NC )
  env init|boot              Setup Initial level environment variables (TZ, USER, UID, GID)

$( $script:CYAN )Misc:$( $script:NC )
  install certificate        Install local rootCA
  notify watch [container]   Watch SERVER_TOOLS notifications and show desktop popups
  notify test "T" "B"        Send a test notification into SERVER_TOOLS
  help                       This help
"@ | Write-Host
}

###############################################################################
# 7. MAIN
###############################################################################
try
{
    Need @('docker')

    Ensure-FilesExist @('/docker/.env', '/configuration/php/php.ini')

    if (-not $args -or $args.Count -lt 1)
    {
        Cmd-Help; exit 1
    }

    $argv = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $args)
    {
        [void]$argv.Add($a)
    }

    while ($argv.Count -gt 0)
    {
        $a = $argv[0]
        switch ($a)
        {
            '-v' {
                $script:VERBOSE = $true;$argv.RemoveAt(0); continue
            }
            '--verbose' {
                $script:VERBOSE = $true;$argv.RemoveAt(0); continue
            }
            '-q' {
                $script:VERBOSE = $false;$argv.RemoveAt(0); continue
            }
            '--quiet' {
                $script:VERBOSE = $false;$argv.RemoveAt(0); continue
            }
            '--' {
                $argv.RemoveAt(0); break
            }
            default {
                if ( $a.StartsWith('-'))
                {
                    Die "Unknown global option: $a"
                }
                break
            }
        }
    }

    if ($argv.Count -lt 1)
    {
        Cmd-Help; exit 1
    }

    $cmd = $argv[0].ToLowerInvariant()
    $rest = if ($argv.Count -gt 1)
    {
        $argv.GetRange(1, $argv.Count - 1).ToArray()
    }
    else
    {
        @()
    }

    $binPass = @('php', 'mariadb', 'mariadb-dump', 'mysql', 'mysql-dump', 'psql', 'pg_dump', 'pg_restore', 'composer')
    if ($binPass -contains $cmd)
    {
        $bin = Join-Path $DIR ("bin/{0}" -f $cmd)
        if (-not (Test-Path -LiteralPath $bin))
        {
            Die "Missing bin wrapper: $bin"
        }
        & $bin @rest
        exit $LASTEXITCODE
    }
    if ($cmd -in @('redis', 'redis-cli'))
    {
        $bin = Join-Path $DIR 'bin/redis-cli'
        if (-not (Test-Path -LiteralPath $bin))
        {
            Die "Missing bin wrapper: $bin"
        }
        & $bin @rest
        exit $LASTEXITCODE
    }

    switch ($cmd)
    {
        'perm' {
            Fix-Perms
        }
        'perms' {
            Fix-Perms
        }
        'permission' {
            Fix-Perms
        }
        'permissions' {
            Fix-Perms
        }

        'up' {
            Cmd-Up $rest
        }
        'start' {
            Cmd-Start $rest
        }
        'reload' {
            Cmd-Reload $rest
        }
        'restart' {
            Cmd-Restart $rest
        }
        'reboot' {
            Cmd-Reboot $rest
        }
        'stop' {
            Cmd-Stop $rest
        }
        'down' {
            Cmd-Down $rest
        }
        'rebuild' {
            Cmd-Rebuild $rest
        }
        'config' {
            Cmd-Config $rest
        }
        'tools' {
            Cmd-Tools $rest
        }
        'lzd' {
            Cmd-Lzd $rest
        }
        'lazydocker' {
            Cmd-Lazydocker $rest
        }
        'http' {
            Cmd-Http $rest
        }
        'core' {
            Cmd-Core $rest
        }
        'cli' {
            Cmd-Cli $rest
        }
        'setup' {
            Cmd-Setup $rest
        }
        'env' {
            Cmd-Env $rest
        }
        'install' {
            Cmd-Install $rest
        }
        'notify' {
            Cmd-Notify $rest
        }
        'help' {
            Cmd-Help
        }
        default {
            Write-Host ""
            Write-Host "$( $script:RED )Error:$( $script:NC ) Unknown command '$cmd'"
            Write-Host ""
            Cmd-Help
            exit 1
        }
    }
}
catch
{
    Write-Host ""
    Write-Host "$( $script:RED )Error:$( $script:NC ) $( $_.Exception.Message )"
    Write-Host ""
    exit 1
}
finally
{
    try
    {
        if ($script:NotifyIcon)
        {
            $script:NotifyIcon.Visible = $false
            $script:NotifyIcon.Dispose()
        }
    }
    catch
    {
    }
}
