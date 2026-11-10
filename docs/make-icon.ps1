# make-icon.ps1 - draws the 007 logo and writes 007.ico (PNG-compressed, multi-size)
# and logo.png into the repo root. Run again after changing the design.

Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

function New-LogoBitmap([int]$size) {
    # 007 "Sweep gauge" logo: dark rounded tile, red 270-degree ring, white 007.
    $s = [single]$size
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $red = [System.Drawing.Color]::FromArgb(232, 52, 52)

    # Rounded tile with a dark gradient
    $x = $s * 0.03; $w = $s - 2 * $x; $r = $s * 0.46
    $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tile.AddArc($x, $x, $r, $r, 180, 90); $tile.AddArc($x + $w - $r, $x, $r, $r, 270, 90)
    $tile.AddArc($x + $w - $r, $x + $w - $r, $r, $r, 0, 90); $tile.AddArc($x, $x + $w - $r, $r, $r, 90, 90)
    $tile.CloseFigure()
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.RectangleF 0, 0, $s, $s), ([System.Drawing.Color]::FromArgb(34, 34, 38)), ([System.Drawing.Color]::FromArgb(12, 12, 14)), ([single]90)
    $g.FillPath($bg, $tile)

    # Gauge ring: faint track plus red sweep
    $c = $s * 0.5; $rr = $s * 0.3; $pw = [math]::Max(1.5, $s * 0.05)
    $track = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(25, 255, 255, 255)), ([single]$pw)
    $sweep = New-Object System.Drawing.Pen $red, ([single]$pw)
    foreach ($p in $track, $sweep) { $p.StartCap = 'Round'; $p.EndCap = 'Round' }
    $g.DrawArc($track, $c - $rr, $c - $rr, 2 * $rr, 2 * $rr, 135, 270)
    $g.DrawArc($sweep, $c - $rr, $c - $rr, 2 * $rr, 2 * $rr, 135, 200)

    # "007" as a path, scaled to fit inside the ring
    $fams = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    $fam = if ($fams -contains 'Bahnschrift') { 'Bahnschrift' } elseif ($fams -contains 'Segoe UI') { 'Segoe UI' } else { 'Arial' }
    $tp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tp.AddString('007', (New-Object System.Drawing.FontFamily $fam), [int][System.Drawing.FontStyle]::Bold, 100, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
    $b = $tp.GetBounds(); $k = [math]::Min(($s * 0.4) / $b.Width, ($s * 0.2) / $b.Height)
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Translate($c, $c); $m.Scale($k, $k); $m.Translate(-($b.X + $b.Width / 2), -($b.Y + $b.Height / 2))
    $tp.Transform($m)
    $g.FillPath([System.Drawing.Brushes]::White, $tp)

    # Soft top highlight
    $g.SetClip($tile)
    $gl = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.RectangleF 0, 0, $s, ($s * 0.5)), ([System.Drawing.Color]::FromArgb(22, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255)), ([single]90)
    $g.FillRectangle($gl, 0, 0, $s, $s * 0.5)
    $g.ResetClip()
    $g.Dispose()
    return $bmp
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$pngs = foreach ($s in $sizes) {
    $b = New-LogoBitmap $s
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
    , $ms.ToArray()
}

$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $out
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $len = $pngs[$i].Length
    $bw.Write([byte]($s % 256)); $bw.Write([byte]($s % 256))
    $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$len); $bw.Write([uint32]$offset)
    $offset += $len
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $root '007.ico'), $out.ToArray())
[System.IO.File]::WriteAllBytes((Join-Path $root 'logo.png'), $pngs[-1])
Write-Host "Wrote 007.ico and logo.png to $root"
