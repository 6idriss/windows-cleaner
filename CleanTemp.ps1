# CleanTemp.ps1 - 007 Clean Temp: a Windows junk cleaner with a GUI.
# Deletes temp files, caches, crash dumps and other junk. Files in use are skipped.
# Does NOT touch: browser history, cookies, passwords, saved logins, documents.
#
# Usage:
#   CleanTemp.ps1          open the app
#   CleanTemp.ps1 -Auto    clean the saved selection silently (used by the weekly task)
#                          -Auto never empties the Recycle Bin.

param([switch]$Auto)

$AppVersion = '2.0.0'
$TaskName   = 'CleanTemp Weekly'

# ---------- Self-elevate to admin ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    if ($Auto) { $argList += ' -Auto' }
    try { Start-Process powershell.exe -Verb RunAs -ArgumentList $argList } catch { }
    exit
}

# ---------- Paths, log, settings ----------
$L  = $env:LOCALAPPDATA
$A  = $env:APPDATA
$W  = $env:SystemRoot
$PD = $env:ProgramData
$DataDir      = Join-Path $L 'CleanTemp'
$LogFile      = Join-Path $DataDir 'log.txt'
$SettingsFile = Join-Path $DataDir 'settings.json'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

function Write-Log([string]$text) { Add-Content -Path $LogFile -Value $text -ErrorAction SilentlyContinue }

function Format-Size([double]$b) {
    if ($b -ge 1GB) { return '{0:N2} GB' -f ($b / 1GB) }
    if ($b -ge 1MB) { return '{0:N1} MB' -f ($b / 1MB) }
    if ($b -ge 1KB) { return '{0:N0} KB' -f ($b / 1KB) }
    return '{0:N0} B' -f $b
}

# ---------- What can be cleaned ----------
# Kind: Folder (clear contents), File (delete files), RecycleBin, Action (run a command)
function New-Target($id, $group, $name, $paths, $default = $true, $kind = 'Folder', $filter = '*', $services = $null, $action = $null) {
    [pscustomobject]@{ Id = $id; Group = $group; Name = $name; Paths = @($paths); Default = $default
                       Kind = $kind; Filter = $filter; Services = $services; Action = $action }
}

$Targets = @(
    New-Target 'usertemp'  'Windows' 'User temp files'           @($env:TEMP, "$L\Temp")
    New-Target 'wintemp'   'Windows' 'Windows temp files'        @("$W\Temp")
    New-Target 'prefetch'  'Windows' 'Prefetch'                  @("$W\Prefetch")
    New-Target 'thumbs'    'Windows' 'Thumbnail cache'           @("$L\Microsoft\Windows\Explorer") $true 'Folder' 'thumbcache_*.db'
    New-Target 'icons'     'Windows' 'Icon cache'                @("$L\Microsoft\Windows\Explorer") $true 'Folder' 'iconcache_*.db'
    New-Target 'inet'      'Windows' 'Internet cache'            @("$L\Microsoft\Windows\INetCache")
    New-Target 'wer'       'Windows' 'Error reports'             @("$PD\Microsoft\Windows\WER\ReportArchive", "$PD\Microsoft\Windows\WER\ReportQueue", "$PD\Microsoft\Windows\WER\Temp", "$L\Microsoft\Windows\WER")
    New-Target 'dumps'     'Windows' 'Crash dumps'               @("$L\CrashDumps", "$W\Minidump", "$W\LiveKernelReports")
    New-Target 'memdump'   'Windows' 'Memory dump (MEMORY.DMP)'  @("$W\MEMORY.DMP") $true 'File'
    New-Target 'logs'      'Windows' 'Setup / CBS / DISM logs'   @("$W\Logs\CBS", "$W\Logs\DISM") $true 'Folder' '*.log'
    New-Target 'fontcache' 'Windows' 'Font cache'                @("$W\ServiceProfiles\LocalService\AppData\Local\FontCache") $true 'Folder' '*.dat'
    New-Target 'wu'        'Windows' 'Windows Update cache'      @("$W\SoftwareDistribution\Download", "$W\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache") $true 'Folder' '*' @('wuauserv', 'bits', 'dosvc')
    New-Target 'recent'    'Windows' 'Recent files list'         @("$A\Microsoft\Windows\Recent\AutomaticDestinations", "$A\Microsoft\Windows\Recent\CustomDestinations") $false

    New-Target 'dx'        'Graphics' 'DirectX shader cache'     @("$L\D3DSCache")
    New-Target 'nvidia'    'Graphics' 'NVIDIA shader cache'      @("$L\NVIDIA\DXCache", "$L\NVIDIA\GLCache", "$L\NVIDIA Corporation\NV_Cache", "$PD\NVIDIA Corporation\NV_Cache")
    New-Target 'amd'       'Graphics' 'AMD shader cache'         @("$L\AMD\DxCache", "$L\AMD\DxcCache", "$L\AMD\GLCache", "$L\AMD\VkCache")

    New-Target 'chrome'    'Browsers (cache only)' 'Chrome'      @("$L\Google\Chrome\User Data\*\Cache", "$L\Google\Chrome\User Data\*\Code Cache", "$L\Google\Chrome\User Data\*\GPUCache", "$L\Google\Chrome\User Data\*\Service Worker\CacheStorage", "$L\Google\Chrome\User Data\ShaderCache", "$L\Google\Chrome\User Data\GrShaderCache")
    New-Target 'edge'      'Browsers (cache only)' 'Edge'        @("$L\Microsoft\Edge\User Data\*\Cache", "$L\Microsoft\Edge\User Data\*\Code Cache", "$L\Microsoft\Edge\User Data\*\GPUCache", "$L\Microsoft\Edge\User Data\*\Service Worker\CacheStorage", "$L\Microsoft\Edge\User Data\ShaderCache", "$L\Microsoft\Edge\User Data\GrShaderCache")
    New-Target 'brave'     'Browsers (cache only)' 'Brave'       @("$L\BraveSoftware\Brave-Browser\User Data\*\Cache", "$L\BraveSoftware\Brave-Browser\User Data\*\Code Cache", "$L\BraveSoftware\Brave-Browser\User Data\*\GPUCache", "$L\BraveSoftware\Brave-Browser\User Data\*\Service Worker\CacheStorage", "$L\BraveSoftware\Brave-Browser\User Data\ShaderCache")
    New-Target 'opera'     'Browsers (cache only)' 'Opera'       @("$L\Opera Software\Opera Stable\Cache", "$A\Opera Software\Opera Stable\Code Cache", "$A\Opera Software\Opera Stable\GPUCache", "$L\Opera Software\Opera GX Stable\Cache", "$A\Opera Software\Opera GX Stable\Code Cache", "$A\Opera Software\Opera GX Stable\GPUCache")
    New-Target 'firefox'   'Browsers (cache only)' 'Firefox'     @("$L\Mozilla\Firefox\Profiles\*\cache2", "$L\Mozilla\Firefox\Profiles\*\startupCache")

    New-Target 'discord'   'Apps' 'Discord cache'                @("$A\discord\Cache", "$A\discord\Code Cache", "$A\discord\GPUCache")
    New-Target 'spotify'   'Apps' 'Spotify cache'                @("$L\Spotify\Data", "$L\Spotify\Browser\Cache")
    New-Target 'teams'     'Apps' 'Teams cache'                  @("$A\Microsoft\Teams\Cache", "$A\Microsoft\Teams\GPUCache", "$A\Microsoft\Teams\Code Cache", "$L\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\Default\Cache")
    New-Target 'launchers' 'Apps' 'Steam / Epic web cache'       @("$L\Steam\htmlcache", "$L\EpicGamesLauncher\Saved\webcache", "$L\EpicGamesLauncher\Saved\webcache_4147", "$L\EpicGamesLauncher\Saved\webcache_4430")
    New-Target 'vscode'    'Apps' 'VS Code cache'                @("$A\Code\Cache", "$A\Code\CachedData", "$A\Code\Code Cache", "$A\Code\GPUCache")
    New-Target 'devcache'  'Apps' 'Developer caches (npm, pip, yarn, NuGet)' @("$L\npm-cache", "$A\npm-cache", "$L\pip\cache", "$L\Yarn\Cache", "$L\NuGet\v3-cache") $false

    New-Target 'dns'       'Extras' 'Flush DNS cache'            @() $true 'Action' '*' $null { ipconfig /flushdns | Out-Null }
    New-Target 'recycle'   'Extras' 'Empty Recycle Bin (cannot be undone)' @() $false 'RecycleBin'
)

# ---------- Measure and clean ----------
function Get-TargetFolders($t) {
    $seen = @{}
    foreach ($p in $t.Paths) {
        if (-not $p) { continue }
        foreach ($i in (Get-Item -Path $p -Force -ErrorAction SilentlyContinue)) {
            $key = $i.FullName.ToLower()
            if ($i.PSIsContainer -and -not $seen.ContainsKey($key)) { $seen[$key] = 1; $i.FullName }
        }
    }
}

function Measure-Target($t) {
    $sum = 0.0
    switch ($t.Kind) {
        'Folder' {
            foreach ($f in (Get-TargetFolders $t)) {
                if ($t.Filter -eq '*') {
                    $s = (Get-ChildItem -LiteralPath $f -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                } else {
                    $s = (Get-ChildItem -LiteralPath $f -Filter $t.Filter -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                }
                if ($s) { $sum += [double]$s }
            }
        }
        'File' {
            foreach ($p in $t.Paths) {
                if (Test-Path -LiteralPath $p) { $sum += [double](Get-Item -LiteralPath $p -Force).Length }
            }
        }
        'RecycleBin' {
            try {
                $sh = New-Object -ComObject Shell.Application
                foreach ($x in $sh.Namespace(10).Items()) { $sum += [double]$x.Size }
            } catch { }
        }
    }
    return [double]$sum
}

function Invoke-Target($t) {
    $before = Measure-Target $t
    if ($t.Services) { Stop-Service $t.Services -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
    try {
        switch ($t.Kind) {
            'Folder' {
                foreach ($f in (Get-TargetFolders $t)) {
                    if ($t.Filter -eq '*') {
                        Get-ChildItem -LiteralPath $f -Force -ErrorAction SilentlyContinue |
                            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    } else {
                        Get-ChildItem -LiteralPath $f -Filter $t.Filter -Force -File -ErrorAction SilentlyContinue |
                            Remove-Item -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            'File'       { foreach ($p in $t.Paths) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } }
            'RecycleBin' { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
            'Action'     { & $t.Action }
        }
    } finally {
        if ($t.Services) { Start-Service $t.Services -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
    }
    $after = Measure-Target $t
    return [math]::Max([double]0, [double]$before - [double]$after)
}

# ---------- Saved selection ----------
function Get-SavedIds {
    if (Test-Path -LiteralPath $SettingsFile) {
        try { return @((Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json).Checked) } catch { }
    }
    return @($Targets | Where-Object Default | ForEach-Object Id)
}
function Save-Ids([string[]]$ids) {
    @{ Checked = @($ids) } | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
}

# ---------- Weekly schedule ----------
function Test-Schedule { [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) }
function Set-Schedule([bool]$on) {
    if ($on) {
        $ps  = Join-Path $W 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $act = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Auto"
        $trg = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '12:00'
        $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        $pr  = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $trg -Settings $set -Principal $pr -Force | Out-Null
    } else {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# ---------- Silent mode (weekly task) ----------
if ($Auto) {
    $ids = Get-SavedIds
    Write-Log ''
    Write-Log "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  auto clean ====="
    $total = 0.0
    foreach ($t in $Targets) {
        if ($t.Kind -eq 'RecycleBin' -or $ids -notcontains $t.Id) { continue }
        $freed = Invoke-Target $t
        $total += $freed
        Write-Log ('  {0,-40} {1,12}' -f $t.Name, (Format-Size $freed))
    }
    Write-Log ('  TOTAL: {0}' -f (Format-Size $total))
    exit
}

# =====================================================================
#                                GUI
# =====================================================================
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$cBg     = [System.Drawing.Color]::FromArgb(20, 20, 20)
$cPanel  = [System.Drawing.Color]::FromArgb(28, 28, 28)
$cHeader = [System.Drawing.Color]::FromArgb(12, 12, 12)
$cText   = [System.Drawing.Color]::FromArgb(230, 230, 230)
$cDim    = [System.Drawing.Color]::FromArgb(140, 140, 140)
$cRed    = [System.Drawing.Color]::FromArgb(214, 40, 40)
$cGreen  = [System.Drawing.Color]::FromArgb(90, 200, 120)

function New-LogoBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $pad = [math]::Max(1, [int]($size * 0.04)); $rad = [int]($size * 0.22); $w = $size - 2 * $pad - 1
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($pad, $pad, $rad, $rad, 180, 90)
    $path.AddArc($pad + $w - $rad, $pad, $rad, $rad, 270, 90)
    $path.AddArc($pad + $w - $rad, $pad + $w - $rad, $rad, $rad, 0, 90)
    $path.AddArc($pad, $pad + $w - $rad, $rad, $rad, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(17, 17, 17))), $path)
    $g.DrawPath((New-Object System.Drawing.Pen $cRed, ([math]::Max(1, $size * 0.045))), $path)
    $fontName = 'Segoe UI Black'
    if (-not ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains $fontName)) { $fontName = 'Arial Black' }
    $em = $size * 0.42
    do {
        $font = New-Object System.Drawing.Font $fontName, $em, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $m = $g.MeasureString('007', $font); $em -= $size * 0.01
    } while ($m.Width -gt $size * 0.84 -and $em -gt 4)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center; $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString('007', $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, (-$size * 0.05), $size, $size), $sf)
    $barW = $size * 0.46
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $cRed), ($size - $barW) / 2, $size * 0.7, $barW, [math]::Max(1, $size * 0.055))
    $g.Dispose()
    return $bmp
}

function New-Button($text, $x, $y, $w, $accent = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Location = New-Object System.Drawing.Point $x, $y; $b.Size = New-Object System.Drawing.Size $w, 34
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 1
    $b.Font = New-Object System.Drawing.Font 'Segoe UI', 9.5, ([System.Drawing.FontStyle]::Bold)
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($accent) { $b.BackColor = $cRed; $b.ForeColor = [System.Drawing.Color]::White; $b.FlatAppearance.BorderColor = $cRed }
    else { $b.BackColor = $cPanel; $b.ForeColor = $cText; $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 70, 70) }
    return $b
}

function Get-FreeText {
    $d = Get-PSDrive C
    'C:  {0} free of {1}' -f (Format-Size $d.Free), (Format-Size ($d.Free + $d.Used))
}

try {
    # --- Form ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "007 Clean Temp  v$AppVersion"
    $form.ClientSize = New-Object System.Drawing.Size 780, 660
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = $cBg
    $form.ForeColor = $cText
    $form.Font = New-Object System.Drawing.Font 'Segoe UI', 9.5
    $icoPath = Join-Path $PSScriptRoot '007.ico'
    if (Test-Path -LiteralPath $icoPath) { $form.Icon = New-Object System.Drawing.Icon $icoPath }

    # --- Header ---
    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point 0, 0; $header.Size = New-Object System.Drawing.Size 780, 100
    $header.BackColor = $cHeader
    $form.Controls.Add($header)

    $logo = New-Object System.Windows.Forms.PictureBox
    $logo.Location = New-Object System.Drawing.Point 20, 14; $logo.Size = New-Object System.Drawing.Size 72, 72
    $logo.Image = New-LogoBitmap 72
    $header.Controls.Add($logo)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'CLEAN TEMP'; $title.AutoSize = $true
    $title.Font = New-Object System.Drawing.Font 'Segoe UI', 22, ([System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.Location = New-Object System.Drawing.Point 104, 16
    $header.Controls.Add($title)

    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = "by 007   |   v$AppVersion   |   junk cleaner for Windows"; $sub.AutoSize = $true
    $sub.ForeColor = $cDim; $sub.Location = New-Object System.Drawing.Point 108, 60
    $header.Controls.Add($sub)

    $diskLbl = New-Object System.Windows.Forms.Label
    $diskLbl.AutoSize = $false; $diskLbl.TextAlign = 'MiddleRight'
    $diskLbl.Size = New-Object System.Drawing.Size 300, 24; $diskLbl.Location = New-Object System.Drawing.Point 460, 38
    $diskLbl.ForeColor = $cText; $diskLbl.Text = Get-FreeText
    $header.Controls.Add($diskLbl)

    $redLine = New-Object System.Windows.Forms.Panel
    $redLine.Location = New-Object System.Drawing.Point 0, 100; $redLine.Size = New-Object System.Drawing.Size 780, 3
    $redLine.BackColor = $cRed
    $form.Controls.Add($redLine)

    # --- List ---
    $list = New-Object System.Windows.Forms.ListView
    $list.Location = New-Object System.Drawing.Point 20, 118; $list.Size = New-Object System.Drawing.Size 740, 380
    $list.View = 'Details'; $list.CheckBoxes = $true; $list.FullRowSelect = $true
    $list.HeaderStyle = 'Nonclickable'; $list.BorderStyle = 'FixedSingle'
    $list.BackColor = $cPanel; $list.ForeColor = $cText
    [void]$list.Columns.Add('Item', 340)
    [void]$list.Columns.Add('Area', 170)
    [void]$list.Columns.Add('Size', 200)
    $saved = Get-SavedIds
    foreach ($t in $Targets) {
        $it = New-Object System.Windows.Forms.ListViewItem $t.Name
        $it.UseItemStyleForSubItems = $false
        [void]$it.SubItems.Add($t.Group)
        $it.SubItems[1].ForeColor = $cDim; $it.SubItems[1].BackColor = $cPanel
        [void]$it.SubItems.Add('-')
        $it.SubItems[2].ForeColor = $cDim; $it.SubItems[2].BackColor = $cPanel
        $it.Tag = $t
        $it.Checked = $saved -contains $t.Id
        [void]$list.Items.Add($it)
    }
    $form.Controls.Add($list)

    # --- Buttons ---
    $btnAll   = New-Button 'Select all'  20  510 110
    $btnNone  = New-Button 'Select none' 140 510 110
    $btnScan  = New-Button 'Scan'        480 510 130
    $btnClean = New-Button 'CLEAN'       630 510 130 $true
    $form.Controls.AddRange(@($btnAll, $btnNone, $btnScan, $btnClean))

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location = New-Object System.Drawing.Point 20, 558; $progress.Size = New-Object System.Drawing.Size 740, 14
    $progress.Style = 'Continuous'
    $form.Controls.Add($progress)

    $status = New-Object System.Windows.Forms.Label
    $status.Location = New-Object System.Drawing.Point 20, 578; $status.Size = New-Object System.Drawing.Size 740, 22
    $status.ForeColor = $cDim; $status.Text = 'Ready.'
    $form.Controls.Add($status)

    $chkWeekly = New-Object System.Windows.Forms.CheckBox
    $chkWeekly.Text = 'Auto-clean every Sunday at 12:00 (uses your selection, never empties the Recycle Bin)'
    $chkWeekly.Location = New-Object System.Drawing.Point 20, 616; $chkWeekly.Size = New-Object System.Drawing.Size 560, 24
    $chkWeekly.ForeColor = $cText
    $chkWeekly.Checked = Test-Schedule
    $form.Controls.Add($chkWeekly)

    $btnLog = New-Button 'Open log' 650 610 110
    $form.Controls.Add($btnLog)

    # --- Helpers ---
    $script:busy = $false
    function Set-Busy([bool]$on) {
        $script:busy = $on
        foreach ($c in @($btnAll, $btnNone, $btnScan, $btnClean, $chkWeekly)) { $c.Enabled = -not $on }
        $form.Cursor = if ($on) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default }
    }
    function Pump { [System.Windows.Forms.Application]::DoEvents() }
    function Get-CheckedIds { @($list.Items | Where-Object Checked | ForEach-Object { $_.Tag.Id }) }

    function Start-Scan {
        Set-Busy $true
        $items = @($list.Items); $n = $items.Count; $i = 0; $total = 0.0
        $progress.Value = 0
        foreach ($it in $items) {
            $t = $it.Tag
            $status.Text = "Scanning: $($t.Name)..."
            $it.SubItems[2].Text = 'scanning...'; $it.SubItems[2].ForeColor = $cDim
            Pump
            if ($t.Kind -eq 'Action') { $it.SubItems[2].Text = '-' }
            else {
                $s = Measure-Target $t
                $it.SubItems[2].Text = Format-Size $s
                $it.SubItems[2].ForeColor = if ($s -gt 0) { $cText } else { $cDim }
                if ($it.Checked) { $total += $s }
            }
            $i++; $progress.Value = [int](100 * $i / $n); Pump
        }
        $status.Text = 'Scan done. Selected items hold {0} of junk. Press CLEAN to delete it.' -f (Format-Size $total)
        $status.ForeColor = $cText
        Set-Busy $false
    }

    function Start-Clean {
        $items = @($list.Items | Where-Object Checked)
        if ($items.Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show('Nothing is selected.', '007 Clean Temp', 'OK', 'Information'); return
        }
        $running = Get-Process chrome, msedge, brave, firefox, opera, discord, spotify, Teams, ms-teams -ErrorAction SilentlyContinue
        if ($running) {
            $names = ($running | Select-Object -ExpandProperty Name -Unique) -join ', '
            $r = [System.Windows.Forms.MessageBox]::Show("These apps are open: $names`n`nClose them for a full clean. Files they use are skipped.`n`nContinue anyway?", '007 Clean Temp', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
        }
        $msg = "Delete junk in $($items.Count) selected items?`n`nDeleted files do not go to the Recycle Bin and cannot be recovered."
        if ([System.Windows.Forms.MessageBox]::Show($msg, '007 Clean Temp', 'YesNo', 'Question') -ne 'Yes') { return }

        Set-Busy $true
        Save-Ids (Get-CheckedIds)
        $freeBefore = [double](Get-PSDrive C).Free
        Write-Log ''
        Write-Log "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ====="
        $n = $items.Count; $i = 0; $total = 0.0
        $progress.Value = 0
        foreach ($it in $items) {
            $t = $it.Tag
            $status.Text = "Cleaning: $($t.Name)..."; $status.ForeColor = $cText
            $it.SubItems[2].Text = 'cleaning...'; $it.SubItems[2].ForeColor = $cDim
            Pump
            $freed = Invoke-Target $t
            $total += $freed
            if ($t.Kind -eq 'Action') { $it.SubItems[2].Text = 'done' ; $it.SubItems[2].ForeColor = $cGreen }
            elseif ($freed -gt 0) { $it.SubItems[2].Text = 'freed ' + (Format-Size $freed); $it.SubItems[2].ForeColor = $cGreen }
            else { $it.SubItems[2].Text = 'nothing to clean'; $it.SubItems[2].ForeColor = $cDim }
            Write-Log ('  {0,-40} {1,12}' -f $t.Name, (Format-Size $freed))
            $i++; $progress.Value = [int](100 * $i / $n); Pump
        }
        $gain = [math]::Max([double]0, [double](Get-PSDrive C).Free - $freeBefore)
        Write-Log ('  TOTAL: {0}' -f (Format-Size $total))
        $diskLbl.Text = Get-FreeText
        $status.Text = 'Done. Removed {0} of junk. C: gained {1}.' -f (Format-Size $total), (Format-Size $gain)
        $status.ForeColor = $cGreen
        Set-Busy $false
    }

    # --- Events ---
    $btnAll.Add_Click({ foreach ($it in $list.Items) { $it.Checked = $it.Tag.Kind -ne 'RecycleBin' -or $it.Checked } })
    $btnNone.Add_Click({ foreach ($it in $list.Items) { $it.Checked = $false } })
    $btnScan.Add_Click({ Start-Scan })
    $btnClean.Add_Click({ Start-Clean })
    $btnLog.Add_Click({ if (Test-Path -LiteralPath $LogFile) { Start-Process notepad.exe -ArgumentList "`"$LogFile`"" } else { [void][System.Windows.Forms.MessageBox]::Show('No log yet. Run a clean first.', '007 Clean Temp') } })
    $chkWeekly.Add_Click({
        try {
            Save-Ids (Get-CheckedIds)
            Set-Schedule $chkWeekly.Checked
            $status.Text = if ($chkWeekly.Checked) { 'Weekly auto-clean is on. It runs every Sunday at 12:00 with your current selection.' } else { 'Weekly auto-clean is off.' }
            $status.ForeColor = $cText
        } catch {
            $chkWeekly.Checked = Test-Schedule
            [void][System.Windows.Forms.MessageBox]::Show("Could not change the schedule:`n$($_.Exception.Message)", '007 Clean Temp', 'OK', 'Error')
        }
    })
    $form.Add_FormClosing({ param($s, $e) if ($script:busy) { $e.Cancel = $true } else { Save-Ids (Get-CheckedIds) } })
    $form.Add_Shown({ $form.Activate(); Start-Scan })

    [void]$form.ShowDialog()
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show("007 Clean Temp hit an error:`n`n$($_.Exception.Message)`n`nLine $($_.InvocationInfo.ScriptLineNumber)", '007 Clean Temp', 'OK', 'Error')
}
