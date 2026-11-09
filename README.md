# CleanTemp

A one-click Windows cleaner. It deletes temp files, caches, crash dumps and other junk, then shows how much space it freed.

No install needed, no background service, no telemetry. It is a single readable PowerShell script.

## Install

### Option 1: one-line install

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/6idriss/windows-cleaner/main/install.ps1 | iex
```

This adds a **Clean Temp** shortcut to your Desktop and Start Menu.

### Option 2: download the zip

1. Download `CleanTemp.zip` from the [latest release](https://github.com/6idriss/windows-cleaner/releases/latest).
2. Extract it.
3. Double-click **Install.bat**, or double-click **Run CleanTemp.bat** to run it once without installing.

If Windows SmartScreen warns you, click **More info** then **Run anyway**. This happens because the files are not code-signed.

## What it cleans

| Area | Items |
|------|-------|
| Windows | User temp, Windows temp, Prefetch, thumbnail and icon cache, Internet cache, error reports, crash dumps, `MEMORY.DMP`, CBS/DISM logs, font cache |
| Windows Update | Download cache, Delivery Optimization cache |
| Graphics | DirectX, NVIDIA and AMD shader caches |
| Browsers | Cache only for Chrome, Edge, Brave, Opera and Firefox |
| Apps | Discord, Spotify, Teams, Steam web cache, VS Code cache |
| Extras | DNS cache flush, Recycle Bin (only if you say yes) |

## What it never touches

Browser history, cookies, passwords, saved logins, your documents, or Spotify offline downloads.

## Notes

- It asks for administrator rights. These are needed for Windows temp, Prefetch and Windows Update folders.
- Files that are in use are skipped. Close your browsers first for a full clean.
- Deleted files do not go to the Recycle Bin and cannot be recovered.
- After a run, apps and games may load a bit slower once while caches rebuild.
- A log of each run is saved to `%LOCALAPPDATA%\CleanTemp\log.txt`.

## Uninstall

Double-click **Uninstall.bat** from the zip, or run:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CleanTemp\install.ps1" -Uninstall
```

## Requirements

Windows 10 or 11 with Windows PowerShell 5.1 (built in).

## License

[MIT](LICENSE)
