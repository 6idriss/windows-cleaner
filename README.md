<p align="center"><img src="logo.png" width="128" alt="007 logo"></p>

<h1 align="center">007 Clean Temp</h1>

<p align="center">A one-click Windows junk cleaner. It scans temp files, caches, crash dumps and other junk, shows how much space each one uses, and deletes the ones you pick.</p>

No background service, no telemetry, no ads. It is one readable PowerShell script.

## Features

- **Scan first.** It shows the size of every item before anything is deleted.
- **Pick what to clean.** Every item has a checkbox. Your choices are saved for next time.
- **Live progress.** A progress bar shows each item and how much it freed.
- **Weekly auto-clean.** One checkbox runs a silent clean every Sunday at 12:00. It never empties the Recycle Bin.
- **Safe by default.** Browser history, cookies, passwords and your files are never touched. Riskier items start unchecked.
- **Log.** Every clean is saved to a log you can open from the app.

## Install

### Option 1: one-line install

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/6idriss/windows-cleaner/main/install.ps1 | iex
```

This adds a **Clean Temp** shortcut with the 007 icon to your Desktop and Start Menu.

### Option 2: download the zip

1. Download `CleanTemp.zip` from the [latest release](https://github.com/6idriss/windows-cleaner/releases/latest).
2. Extract it.
3. Double-click **Install.bat**, or double-click **Run CleanTemp.bat** to run it once without installing.

If Windows SmartScreen warns you, click **More info** then **Run anyway**. This happens because the files are not code-signed.

## What it cleans

| Area | Items | Checked by default |
|------|-------|--------------------|
| Windows | User temp, Windows temp, Prefetch, thumbnail and icon cache, Internet cache, error reports, crash dumps, `MEMORY.DMP`, CBS/DISM logs, font cache, Windows Update and Delivery Optimization cache | Yes |
| Windows | Recent files list | No |
| Graphics | DirectX, NVIDIA and AMD shader caches | Yes |
| Browsers | Cache only for Chrome, Edge, Brave, Opera, Opera GX and Firefox | Yes |
| Apps | Discord, Spotify, Teams, Steam and Epic web cache, VS Code | Yes |
| Apps | Developer caches: npm, pip, Yarn, NuGet | No |
| Extras | Flush DNS cache | Yes |
| Extras | Empty Recycle Bin | No |

## What it never touches

Browser history, cookies, passwords, saved logins, your documents, or Spotify offline downloads.

## Notes

- It asks for administrator rights. These are needed for Windows temp, Prefetch and Windows Update folders.
- Files that are in use are skipped. The app warns you when browsers or other apps are open.
- Deleted files do not go to the Recycle Bin and cannot be recovered.
- After a clean, apps and games may load a bit slower once while caches rebuild.
- Settings and the log are in `%LOCALAPPDATA%\CleanTemp`.

## Command line

```powershell
CleanTemp.ps1          # open the app
CleanTemp.ps1 -Auto    # clean your saved selection silently, no window
```

## Uninstall

Double-click **Uninstall.bat** from the zip, or run:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\CleanTemp\install.ps1" -Uninstall
```

This also removes the weekly task if you turned it on.

## Requirements

Windows 10 or 11 with Windows PowerShell 5.1 (built in).

## License

[MIT](LICENSE)
