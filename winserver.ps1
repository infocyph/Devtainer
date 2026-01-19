#!/usr/bin/env pwsh
<#
winserver.ps1 - Devtainer CLI launcher (PowerShell port)
Usage:
  .\winserver.bat help
  .\winserver.bat start
  .\winserver.bat -v config
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Die([string]$Message) { throw $Message }

###############################################################################
# 0. PATHS & CONSTANTS
###############################################################################
$ScriptPath = $MyInvocation.MyCommand.Path
$DIR = Split-Path -Parent (Resolve-Path -LiteralPath $ScriptPath)

$CFG = Join-Path $DIR 'docker'
$ENV_MAIN = Join-Path $DIR '.env'
$ENV_DOCKER = Join-Path $CFG '.env'
$COMPOSE_FILE = Join-Path $CFG 'compose/main.yaml'

function Ansi([string]$code) { "`e[$code" + "m" }
$script:RED     = Ansi '0;31'
$script:GREEN   = Ansi '0;32'
$script:CYAN    = Ansi '0;36'
$script:YELLOW  = Ansi '1;33'
$script:BLUE    = Ansi '0;34'
$script:MAGENTA = Ansi '0;35'
$script:WHITE   = Ansi '0;37'
$script:NC      = Ansi '0'

# Default: QUIET
$script:VERBOSE = $false

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
            if (Get-Command $cmd -ErrorAction SilentlyContinue) { $found = $true; break }
        }
        if (-not $found)
        {
            Die ("Missing command(s): {0}" -f ($alts -join ' or '))
        }
    }
}

function LogV([string]$Tag, [string]$Msg)
{
    if ($script:VERBOSE) { [Console]::Error.WriteLine("$($script:CYAN)[$Tag]$($script:NC) $Msg") }
}
function LogQ([string]$Tag, [string]$Msg)
{
    [Console]::Error.WriteLine("$($script:CYAN)[$Tag]$($script:NC) $Msg")
}

function Is-WindowsLike { return ($env:OS -eq 'Windows_NT') }

function Ensure-FilesExist([string[]]$RelPaths)
{
    foreach ($rel in $RelPaths)
    {
        $r = $rel.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
        $abs = Join-Path $DIR $r
        $d = Split-Path -Parent $abs

        if (-not (Test-Path -LiteralPath $d))
        {
            try { New-Item -ItemType Directory -Path $d -Force | Out-Null }
            catch { Write-Host "$($script:YELLOW)- Warning:$($script:NC) cannot create directory $d"; continue }
        }
        elseif (-not (Test-Path -LiteralPath $d -PathType Container))
        {
            Write-Host "$($script:YELLOW)- Warning:$($script:NC) not a directory: $d"
            continue
        }

        if (Test-Path -LiteralPath $abs)
        {
            try
            {
                if (Is-WindowsLike)
                {
                    $item = Get-Item -LiteralPath $abs -Force -ErrorAction SilentlyContinue
                    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReadOnly))
                    {
                        $item.Attributes = ($item.Attributes -bxor [IO.FileAttributes]::ReadOnly)
                    }
                }

                $fs = [IO.File]::Open($abs, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
                $fs.Close()
            }
            catch
            {
                Write-Host "$($script:YELLOW)- Warning:$($script:NC) file not writable: $abs"
            }
        }
        else
        {
            try { New-Item -ItemType File -Path $abs -Force | Out-Null }
            catch { Write-Host "$($script:RED)- Error:$($script:NC) cannot create file $abs"; }
        }
    }
}

function Update-Env([string]$File, [string]$Var, [string]$Val)
{
    $parent = Split-Path -Parent $File
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $File)) { New-Item -ItemType File -Path $File -Force | Out-Null }

    $lines = @(Get-Content -LiteralPath $File -ErrorAction SilentlyContinue)
    if ($null -eq $lines) { $lines = @() }

    $escaped = [Regex]::Escape($Var)
    $rx = "^[# ]*${escaped}="

    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        if ($lines[$i] -match $rx)
        {
            $lines[$i] = "$Var=$Val"
            $updated = $true
            break
        }
    }
    if (-not $updated) { $lines += "$Var=$Val" }

    $tmp = "$File.tmp"
    Set-Content -LiteralPath $tmp -Value $lines -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $File -Force
}

###############################################################################
# Docker compose wrapper
###############################################################################
function Docker-Compose
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & docker compose --project-directory $DIR -f $COMPOSE_FILE --env-file $ENV_DOCKER @Args
}
function Dc-Up
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE) { Docker-Compose @Args } else { Docker-Compose up --quiet-pull @Args }
}
function Dc-Pull
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE) { Docker-Compose pull @Args } else { Docker-Compose pull -q @Args }
}
function Dc-Build
{
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($script:VERBOSE) { Docker-Compose build @Args } else { Docker-Compose build --quiet @Args }
}

function Http-Reload
{
    Write-Host "$($script:GREEN)Reloading HTTP...$($script:NC)"
    try { $ng = (& docker ps -qf name=NGINX 2> $null); if ($ng) { & docker exec NGINX nginx -s reload 2> $null | Out-Null } } catch { }
    try { $ap = (& docker ps -qf name=APACHE 2> $null); if ($ap) { & docker exec APACHE apachectl graceful 2> $null | Out-Null } } catch { }
    Write-Host "$($script:GREEN)HTTP reloaded$($script:NC)"
}

###############################################################################
# PERMS (Windows)
###############################################################################
function Fix-Perms
{
    if (-not (Is-WindowsLike))
    {
        Write-Host "$($script:YELLOW)Fix-Perms is Windows-only in winserver.ps1.$($script:NC)"
        return
    }

    $root = $DIR
    $userHome = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($userHome)) { Die 'USERPROFILE is not set.' }

    $userBin = Join-Path $userHome 'bin'
    $projBin = Join-Path $root 'bin'
    $targetBat = Join-Path $root 'winserver.bat'
    if (-not (Test-Path -LiteralPath $targetBat)) { Die "winserver.bat not found at: $targetBat" }

    if (-not (Test-Path -LiteralPath $userBin)) { New-Item -ItemType Directory -Path $userBin -Force | Out-Null }

    $shim = Join-Path $userBin 'winserver.cmd'
    $shimBody = "@echo off`r`ncall `"$targetBat`" %*`r`n"
    Set-Content -LiteralPath $shim -Value $shimBody -Encoding Ascii

    function Normalize-Path([string]$p)
    {
        if ([string]::IsNullOrWhiteSpace($p)) { return '' }
        $x = $p.Trim()
        while ($x.EndsWith('\') -or $x.EndsWith('/')) { $x = $x.Substring(0, $x.Length - 1) }
        return $x.ToLowerInvariant()
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $userPath) { $userPath = '' }

    $parts = @()
    foreach ($pp in ($userPath -split ';')) { $t = $pp.Trim(); if ($t) { $parts += $t } }

    $need = @($userBin, $projBin)
    $changed = $false

    foreach ($add in $need)
    {
        $nAdd = Normalize-Path $add
        $exists = $false
        foreach ($pp in $parts) { if ((Normalize-Path $pp) -eq $nAdd) { $exists = $true; break } }
        if (-not $exists) { $parts += $add; $changed = $true }

        $envExists = $false
        foreach ($ep in ($env:Path -split ';')) { if ((Normalize-Path $ep) -eq $nAdd) { $envExists = $true; break } }
        if (-not $envExists) { $env:Path = ($env:Path.TrimEnd(';') + ';' + $add) }
    }

    if ($changed) { [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User') }

    Write-Host "$($script:GREEN)Installed Windows shim + PATH.$($script:NC)"
    Write-Host "  shim : $shim"
    Write-Host "  PATH+: $userBin"
    Write-Host "  PATH+: $projBin"
    Write-Host "$($script:YELLOW)Open a NEW terminal to pick up User PATH changes system-wide.$($script:NC)"
}

###############################################################################
# HELP
###############################################################################
function Cmd-Help
{
    @"
$($script:CYAN)Usage:$($script:NC) winserver [--verbose|-v] <command> [options]

$($script:CYAN)Core:$($script:NC)
  up / start
  stop / down
  reload / restart
  rebuild all|<svc...>
  config
  tools
  lzd | lazydocker
  http reload
  core <domain>

$($script:CYAN)Setup:$($script:NC)
  setup permissions
  setup domain
  setup profiles

$($script:CYAN)Env:$($script:NC)
  env init|boot

$($script:CYAN)Misc:$($script:NC)
  install certificate
  notify watch [container]
  notify test "T" "B"
  help
"@ | Write-Host
}

###############################################################################
# MINIMAL stubs (keep your existing ones if you already have them)
# (Your previous features: profiles/domain/rebuild/notify/etc can stay as-is)
###############################################################################
function Cmd-Up([string[]]$Args) { Dc-Up @Args }
function Cmd-Start([string[]]$Args)
{
    Dc-Up -d @Args
    Http-Reload
    if (-not $script:VERBOSE)
    {
        Write-Host "$($script:GREEN)OK: stack started (quiet). Use -v to see compose output.$($script:NC)"
    }
}
function Cmd-Stop([string[]]$Args) { Docker-Compose down }
function Cmd-Config([string[]]$Args) { Docker-Compose config }

###############################################################################
# 7. MAIN (IMPORTANT CHANGE: resolve help FIRST, before docker/files)
###############################################################################
try
{
    if (-not $args -or $args.Count -lt 1) { Cmd-Help; exit 1 }

    $argv = New-Object System.Collections.Generic.List[string]
    foreach ($a in $args) { [void]$argv.Add($a) }

    while ($argv.Count -gt 0)
    {
        $a = $argv[0]
        switch ($a)
        {
            '-v'        { $script:VERBOSE = $true;  $argv.RemoveAt(0); continue }
            '--verbose' { $script:VERBOSE = $true;  $argv.RemoveAt(0); continue }
            '-q'        { $script:VERBOSE = $false; $argv.RemoveAt(0); continue }
            '--quiet'   { $script:VERBOSE = $false; $argv.RemoveAt(0); continue }
            '--'        { $argv.RemoveAt(0); break }
            default {
                if ($a.StartsWith('-')) { Die "Unknown global option: $a" }
                break
            }
        }
    }

    if ($argv.Count -lt 1) { Cmd-Help; exit 1 }

    $cmd = $argv[0].ToLowerInvariant()
    $rest = if ($argv.Count -gt 1) { $argv.GetRange(1, $argv.Count - 1).ToArray() } else { @() }

    # ✅ Help must never touch docker/fs
    if ($cmd -in @('help','-h','--help'))
    {
        Cmd-Help
        exit 0
    }

    # Everything else: now require docker + ensure files
    Need @('docker')
    Ensure-FilesExist @('/docker/.env', '/configuration/php/php.ini')

    switch ($cmd)
    {
        'perm'        { Fix-Perms }
        'perms'       { Fix-Perms }
        'permission'  { Fix-Perms }
        'permissions' { Fix-Perms }

        'up'     { Cmd-Up $rest }
        'start'  { Cmd-Start $rest }
        'stop'   { Cmd-Stop $rest }
        'down'   { Cmd-Stop $rest }
        'config' { Cmd-Config $rest }

        default {
            Write-Host ""
            Write-Host "$($script:RED)Error:$($script:NC) Unknown command '$cmd'"
            Write-Host ""
            Cmd-Help
            exit 1
        }
    }
}
catch
{
    Write-Host ""
    Write-Host "$($script:RED)Error:$($script:NC) $($_.Exception.Message)"
    Write-Host ""
    exit 1
}
