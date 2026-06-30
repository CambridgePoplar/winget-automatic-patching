#Requires -Version 5.1
<#
    Runs `winget upgrade --all` in the calling context and overwrites a per-scope log file
    at C:\ProgramData\WinGetAutoPatch\Logs\<Scope>.log with the result.
    Invoked by the "WinGet Auto Patch (System)" and "WinGet Auto Patch (User)" scheduled tasks.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('System', 'User')]
    [string]$Scope
)

$LogDir = 'C:\ProgramData\WinGetAutoPatch\Logs'
$LogPath = Join-Path $LogDir "$Scope.log"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Get-WinGetPath {
    # winget is a per-user app execution alias, so it isn't always on PATH (notably for SYSTEM).
    # Fall back to locating the DesktopAppInstaller package directly under WindowsApps.
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $package = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Filter 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -Directory -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '.*_(\d+\.\d+\.\d+\.\d+)_.*', '$1') } -Descending |
        Select-Object -First 1

    if ($package) { return Join-Path $package.FullName 'winget.exe' }
    return $null
}

$log = [System.Collections.Generic.List[string]]::new()
$log.Add("WinGet Auto Patch - $Scope context")
$log.Add("Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$log.Add('')

$wingetPath = Get-WinGetPath

if (-not $wingetPath) {
    $log.Add('ERROR: winget.exe was not found in this context.')
    $log | Set-Content -Path $LogPath -Encoding UTF8
    exit 1
}

$output = & $wingetPath upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1
$exitCode = $LASTEXITCODE
$log.AddRange([string[]]$output)
$log.Add('')
$log.Add("winget exit code: $exitCode")

$log | Set-Content -Path $LogPath -Encoding UTF8
exit $exitCode
