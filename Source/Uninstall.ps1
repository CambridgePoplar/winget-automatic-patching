#Requires -Version 5.1
<#
    Intune Win32 app uninstall script. Removes the scheduled tasks, installed files,
    logs, and the registry detection key created by Install.ps1.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

Unregister-ScheduledTask -TaskName 'WinGet Auto Patch (System)' -Confirm:$false
Unregister-ScheduledTask -TaskName 'WinGet Auto Patch (User)' -Confirm:$false

Remove-Item -Path (Join-Path $env:ProgramFiles 'WinGetAutoPatch') -Recurse -Force
Remove-Item -Path 'C:\ProgramData\WinGetAutoPatch' -Recurse -Force
Remove-Item -Path 'HKLM:\SOFTWARE\WinGetAutoPatch' -Recurse -Force
