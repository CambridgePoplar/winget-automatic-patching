# WinGet Automatic Patching

Silently keeps every winget-installed app up to date on a Windows machine, in both
machine-wide and per-user contexts, via two scheduled tasks that run at logon.

## How it works

`Install.ps1` copies `Update-WinGetApps.ps1` to `C:\Program Files\WinGetAutoPatch\`
(always the real Program Files, never the x86 redirect) and registers two scheduled tasks.
It also starts both tasks immediately so patching doesn't wait for the next logon (the user
task is skipped at install time if no one is interactively logged on yet — the logon trigger
still covers that case):

| Task | Runs as | Trigger | Covers |
|---|---|---|---|
| `WinGet Auto Patch (System)` | `NT AUTHORITY\SYSTEM` | At logon | Machine-wide winget sources |
| `WinGet Auto Patch (User)` | The logged-on user | At logon | Per-user winget sources |

Both run `winget upgrade --all --silent` with no visible window or prompts, and each
overwrites its own log on every run at:

```
C:\ProgramData\WinGetAutoPatch\Logs\System.log
C:\ProgramData\WinGetAutoPatch\Logs\User.log
```

## Intune deployment

Package `Source/` as a Win32 app (`.intunewin`) — see [Build](#build) below — then configure:

**Install command**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1
```

**Uninstall command**
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1
```

**Install behavior:** System

### Detection rules

Pick one (registry is recommended — it also lets Intune detect version upgrades via supersedence):

1. **Registry (recommended)**
   - Rule type: Registry
   - Key path: `HKEY_LOCAL_MACHINE\SOFTWARE\WinGetAutoPatch`
   - Value name: `Version`
   - Detection method: `String comparison` → `Equals` → `1.0.1` (or `Value exists` for a looser check)

2. **File**
   - Rule type: File
   - Path: `C:\Program Files\WinGetAutoPatch`
   - File: `Update-WinGetApps.ps1`
   - Detection method: `File or folder exists`

3. **Custom script**
   ```powershell
   $tasks = Get-ScheduledTask -TaskName 'WinGet Auto Patch (System)', 'WinGet Auto Patch (User)' -ErrorAction SilentlyContinue
   if ($tasks.Count -eq 2) { Write-Output 'Installed' }
   ```

## Build

GitHub Actions (`.github/workflows/build-intunewin.yml`) builds the `.intunewin` package:

- Trigger manually from the **Actions** tab (`workflow_dispatch`), or push a tag matching `v*`
  (e.g. `v1.0.0`) to also attach it to a GitHub Release.
- The workflow downloads Microsoft's `IntuneWinAppUtil.exe`, packages `Source/` with
  `Install.ps1` as the setup file, and uploads the result as a build artifact named
  `WinGetAutoPatch-intunewin`.

Bump `$ScriptVersion` in `Source/Install.ps1` before tagging a new release so the registry
detection value stays in sync with the README.

## Local testing

Run as administrator on a test machine:

```powershell
.\Source\Install.ps1
schtasks /run /tn "WinGet Auto Patch (System)"
schtasks /run /tn "WinGet Auto Patch (User)"
```

Then check `C:\ProgramData\WinGetAutoPatch\Logs\`. To remove everything:

```powershell
.\Source\Uninstall.ps1
```

## Requirements

- Windows 10 2004+ / Windows 11
- App Installer (winget) present on the device
