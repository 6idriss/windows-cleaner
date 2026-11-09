# install.ps1 - installs CleanTemp for the current user.
# Copies CleanTemp.ps1 to %LOCALAPPDATA%\CleanTemp and adds Desktop + Start Menu shortcuts.
# Works from an extracted release zip, or online:
#   irm https://raw.githubusercontent.com/6idriss/windows-cleaner/main/install.ps1 | iex
# Uninstall:  powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall

param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$repoRaw    = 'https://raw.githubusercontent.com/6idriss/windows-cleaner/main'
$installDir = Join-Path $env:LOCALAPPDATA 'CleanTemp'
$target     = Join-Path $installDir 'CleanTemp.ps1'
$desktopLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Clean Temp.lnk'
$startLnk   = Join-Path ([Environment]::GetFolderPath('Programs')) 'Clean Temp.lnk'

if ($Uninstall) {
    Remove-Item -LiteralPath $desktopLnk, $startLnk -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'CleanTemp uninstalled.' -ForegroundColor Green
    return
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

# Use the local copy if this runs from an extracted zip, otherwise download it.
$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'CleanTemp.ps1' } else { $null }
if ($local -and (Test-Path -LiteralPath $local)) {
    Copy-Item -LiteralPath $local -Destination $target -Force
} else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "$repoRaw/CleanTemp.ps1" -OutFile $target -UseBasicParsing
}
Unblock-File -LiteralPath $target -ErrorAction SilentlyContinue

# Keep a copy of this installer so uninstall works later.
$selfCopy = Join-Path $installDir 'install.ps1'
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    if ($PSCommandPath -ne $selfCopy) { Copy-Item -LiteralPath $PSCommandPath -Destination $selfCopy -Force }
} else {
    Invoke-WebRequest -Uri "$repoRaw/install.ps1" -OutFile $selfCopy -UseBasicParsing
}

$ps   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$lnkArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$target`""
$ws   = New-Object -ComObject WScript.Shell
foreach ($lnk in @($desktopLnk, $startLnk)) {
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath       = $ps
    $s.Arguments        = $lnkArgs
    $s.WorkingDirectory = $installDir
    $s.IconLocation     = "$env:SystemRoot\System32\imageres.dll,50"
    $s.Description      = 'Delete temp files, caches and other junk'
    $s.Save()
}

Write-Host ''
Write-Host 'CleanTemp installed.' -ForegroundColor Green
Write-Host "  Program:   $target"
Write-Host '  Shortcuts: Desktop and Start Menu ("Clean Temp")'
