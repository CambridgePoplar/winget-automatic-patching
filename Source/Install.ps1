#Requires -Version 5.1
<#
    Intune Win32 app install script. Deploys Update-WinGetApps.ps1 to Program Files and
    registers two scheduled tasks that run it at logon: one as SYSTEM (machine-wide winget
    sources), one as the interactive user (per-user winget sources).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Re-launch under 64-bit PowerShell so $env:ProgramFiles resolves to "Program Files",
# not "Program Files (x86)", regardless of which PowerShell host Intune invokes.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    $sysnative = Join-Path $env:WINDIR 'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
    & $sysnative -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$ScriptVersion = '1.0.0'
$InstallDir = Join-Path $env:ProgramFiles 'WinGetAutoPatch'
$LogDir = 'C:\ProgramData\WinGetAutoPatch\Logs'
$SourceFile = Join-Path $PSScriptRoot 'Update-WinGetApps.ps1'
$ScriptPath = Join-Path $InstallDir 'Update-WinGetApps.ps1'

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
Copy-Item -Path $SourceFile -Destination $InstallDir -Force

# Standard users need write access to overwrite their own log file on each run.
icacls $LogDir /grant '*S-1-5-32-545:(OI)(CI)M' /T | Out-Null

$systemAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Scope System"
$systemTrigger = New-ScheduledTaskTrigger -AtLogOn
$systemPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$systemSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'WinGet Auto Patch (System)' -Action $systemAction -Trigger $systemTrigger -Principal $systemPrincipal -Settings $systemSettings -Force | Out-Null

$userAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Scope User"
$userTrigger = New-ScheduledTaskTrigger -AtLogOn
$userPrincipal = New-ScheduledTaskPrincipal -GroupId 'BUILTIN\Users' -RunLevel Limited
$userSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'WinGet Auto Patch (User)' -Action $userAction -Trigger $userTrigger -Principal $userPrincipal -Settings $userSettings -Force | Out-Null

$RegKey = 'HKLM:\SOFTWARE\WinGetAutoPatch'
New-Item -Path $RegKey -Force | Out-Null
New-ItemProperty -Path $RegKey -Name 'Version' -Value $ScriptVersion -PropertyType String -Force | Out-Null
New-ItemProperty -Path $RegKey -Name 'InstallDate' -Value (Get-Date -Format 'yyyy-MM-dd') -PropertyType String -Force | Out-Null
