# CleanTemp.ps1 - deletes temp files, caches, crash dumps and other junk.
# Files in use are skipped. Shows space freed per item and writes a log.
# Does NOT touch: browser history, cookies, passwords, saved logins, documents.

# ---------- Self-elevate to admin ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$Host.UI.RawUI.WindowTitle = 'Clean Temp'
$L = $env:LOCALAPPDATA
$A = $env:APPDATA
$logDir = Join-Path $L 'CleanTemp'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir 'log.txt'
$script:total = 0

function Format-Size([double]$b) {
    if ($b -ge 1GB) { return '{0:N2} GB' -f ($b / 1GB) }
    if ($b -ge 1MB) { return '{0:N1} MB' -f ($b / 1MB) }
    if ($b -ge 1KB) { return '{0:N0} KB' -f ($b / 1KB) }
    return '{0:N0} B' -f $b
}

function Get-FolderSize([string]$p) {
    $s = (Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s) { return [double]$s } else { return 0 }
}

# Clears the CONTENTS of every folder matching $paths (wildcards allowed).
# $filter limits deletion to matching file names (for example 'thumbcache_*.db').
function Clear-Target([string]$name, [string[]]$paths, [string]$filter = '*') {
    $freed = 0
    foreach ($pattern in $paths) {
        $folders = Get-Item -Path $pattern -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
        foreach ($f in $folders) {
            $before = Get-FolderSize $f.FullName
            if ($filter -eq '*') {
                Get-ChildItem -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Get-ChildItem -LiteralPath $f.FullName -Filter $filter -Force -File -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            $after = Get-FolderSize $f.FullName
            $freed += [math]::Max([double]0, [double]($before - $after))
        }
    }
    $script:total += $freed
    $line = '  {0,-34} {1,12}' -f $name, (Format-Size $freed)
    if ($freed -gt 0) { Write-Host $line -ForegroundColor Green } else { Write-Host $line -ForegroundColor DarkGray }
    Add-Content -Path $logFile -Value $line
}

function Clear-File([string]$name, [string[]]$files) {
    $freed = 0
    foreach ($file in $files) {
        if (Test-Path -LiteralPath $file) {
            $size = (Get-Item -LiteralPath $file -Force).Length
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $file)) { $freed += $size }
        }
    }
    $script:total += $freed
    $line = '  {0,-34} {1,12}' -f $name, (Format-Size $freed)
    if ($freed -gt 0) { Write-Host $line -ForegroundColor Green } else { Write-Host $line -ForegroundColor DarkGray }
    Add-Content -Path $logFile -Value $line
}

function Write-Section([string]$t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }

# ---------- Start ----------
Clear-Host
Write-Host '======================================' -ForegroundColor Cyan
Write-Host '            CLEAN TEMP' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

$running = Get-Process chrome, msedge, brave, firefox, opera, discord -ErrorAction SilentlyContinue
if ($running) {
    $names = ($running | Select-Object -ExpandProperty Name -Unique) -join ', '
    Write-Host ''
    Write-Host "Open now: $names" -ForegroundColor Yellow
    Write-Host 'Close them first to clear their caches fully. Locked files are skipped.' -ForegroundColor Yellow
    Read-Host 'Press Enter to continue'
}

$emptyBin = (Read-Host 'Also empty the Recycle Bin? It cannot be undone. (y/N)') -match '^[yY]'

$drive = Get-PSDrive C
$freeBefore = $drive.Free
Add-Content -Path $logFile -Value ''
Add-Content -Path $logFile -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====="

# ---------- Windows ----------
Write-Section 'Windows'
Clear-Target 'User temp'              @($env:TEMP, "$L\Temp")
Clear-Target 'Windows temp'           @("$env:SystemRoot\Temp")
Clear-Target 'Prefetch'               @("$env:SystemRoot\Prefetch")
Clear-Target 'Thumbnail cache'        @("$L\Microsoft\Windows\Explorer") 'thumbcache_*.db'
Clear-Target 'Icon cache'             @("$L\Microsoft\Windows\Explorer") 'iconcache_*.db'
Clear-Target 'Internet cache'         @("$L\Microsoft\Windows\INetCache")
Clear-Target 'Error reports'          @("$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue", "$env:ProgramData\Microsoft\Windows\WER\Temp", "$L\Microsoft\Windows\WER")
Clear-Target 'Crash dumps'            @("$L\CrashDumps", "$env:SystemRoot\Minidump", "$env:SystemRoot\LiveKernelReports")
Clear-File   'Memory dump'            @("$env:SystemRoot\MEMORY.DMP")
Clear-Target 'Setup / CBS logs'       @("$env:SystemRoot\Logs\CBS", "$env:SystemRoot\Logs\DISM") '*.log'
Clear-Target 'Font cache'             @("$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache") '*.dat'

# Windows Update download cache: services must be stopped first.
Write-Host '  (stopping Windows Update services...)' -ForegroundColor DarkGray
Stop-Service wuauserv, bits, dosvc -Force -ErrorAction SilentlyContinue
Clear-Target 'Windows Update downloads' @("$env:SystemRoot\SoftwareDistribution\Download")
Clear-Target 'Delivery Optimization'    @("$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
Start-Service wuauserv, bits, dosvc -ErrorAction SilentlyContinue

# ---------- Graphics shader caches (rebuilt automatically) ----------
Write-Section 'Graphics caches'
Clear-Target 'DirectX shader cache'   @("$L\D3DSCache")
Clear-Target 'NVIDIA shader cache'    @("$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache", "$L\NVIDIA Corporation\NV_Cache", "$env:ProgramData\NVIDIA Corporation\NV_Cache")
Clear-Target 'AMD shader cache'       @("$L\AMD\DxCache", "$L\AMD\DxcCache", "$L\AMD\GLCache", "$L\AMD\VkCache")

# ---------- Browsers: cache only, NOT history / cookies / passwords ----------
Write-Section 'Browser caches'
$chromium = @{
    'Chrome' = "$L\Google\Chrome\User Data"
    'Edge'   = "$L\Microsoft\Edge\User Data"
    'Brave'  = "$L\BraveSoftware\Brave-Browser\User Data"
    'Opera'  = "$A\Opera Software\Opera Stable"
}
foreach ($b in $chromium.Keys) {
    $root = $chromium[$b]
    Clear-Target "$b cache" @(
        "$root\*\Cache", "$root\*\Code Cache", "$root\*\GPUCache",
        "$root\*\Service Worker\CacheStorage", "$root\ShaderCache", "$root\GrShaderCache",
        "$root\Cache", "$root\Code Cache", "$root\GPUCache"
    )
}
Clear-Target 'Firefox cache' @("$L\Mozilla\Firefox\Profiles\*\cache2", "$L\Mozilla\Firefox\Profiles\*\startupCache")

# ---------- Apps ----------
Write-Section 'Apps'
Clear-Target 'Discord cache'          @("$A\discord\Cache", "$A\discord\Code Cache", "$A\discord\GPUCache")
Clear-Target 'Spotify cache'          @("$L\Spotify\Data", "$L\Spotify\Browser\Cache")
Clear-Target 'Teams cache'            @("$A\Microsoft\Teams\Cache", "$A\Microsoft\Teams\GPUCache", "$A\Microsoft\Teams\Code Cache", "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\Default\Cache")
Clear-Target 'Steam web cache'        @("$L\Steam\htmlcache")
Clear-Target 'VS Code cache'          @("$A\Code\Cache", "$A\Code\CachedData", "$A\Code\Code Cache", "$A\Code\GPUCache")

# ---------- Extras ----------
Write-Section 'Extras'
ipconfig /flushdns | Out-Null
Write-Host '  DNS cache flushed' -ForegroundColor Green
if ($emptyBin) {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host '  Recycle Bin emptied' -ForegroundColor Green
    Add-Content -Path $logFile -Value '  Recycle Bin emptied'
}

# ---------- Summary ----------
$freeAfter = (Get-PSDrive C).Free
$diskGain = [math]::Max([double]0, [double]$freeAfter - [double]$freeBefore)
Write-Host ''
Write-Host '======================================' -ForegroundColor Cyan
Write-Host ('  Junk removed:      {0}' -f (Format-Size $script:total)) -ForegroundColor Green
Write-Host ('  C: free space now: {0}  (+{1})' -f (Format-Size $freeAfter), (Format-Size $diskGain)) -ForegroundColor Green
Write-Host '======================================' -ForegroundColor Cyan
Write-Host "Log: $logFile" -ForegroundColor DarkGray
Add-Content -Path $logFile -Value ('  TOTAL: {0}' -f (Format-Size $script:total))
Write-Host ''
Read-Host 'Press Enter to close'
