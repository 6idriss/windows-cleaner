# make-icon.ps1 - draws the 007 logo and writes 007.ico (PNG-compressed, multi-size)
# and logo.png into the repo root. Run again after changing the design.

Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

function New-LogoBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    # Rounded dark tile with a red border
    $pad = [math]::Max(1, [int]($size * 0.04))
    $rad = [int]($size * 0.22)
    $w = $size - 2 * $pad - 1
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($pad, $pad, $rad, $rad, 180, 90)
    $path.AddArc($pad + $w - $rad, $pad, $rad, $rad, 270, 90)
    $path.AddArc($pad + $w - $rad, $pad + $w - $rad, $rad, $rad, 0, 90)
    $path.AddArc($pad, $pad + $w - $rad, $rad, $rad, 90, 90)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 17, 17, 17))), $path)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 214, 40, 40)), ([math]::Max(1, $size * 0.045))
    $g.DrawPath($pen, $path)

    # "007" text, sized to fit the tile
    $fontName = 'Segoe UI Black'
    if (-not ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains $fontName)) { $fontName = 'Arial Black' }
    $em = $size * 0.42
    do {
        $font = New-Object System.Drawing.Font $fontName, $em, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $m = $g.MeasureString('007', $font)
        $em -= $size * 0.01
    } while ($m.Width -gt $size * 0.84 -and $em -gt 4)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF 0, (-$size * 0.05), $size, $size
    $g.DrawString('007', $font, [System.Drawing.Brushes]::White, $rect, $sf)

    # Red accent bar under the text
    if ($size -ge 24) {
        $barW = $size * 0.46; $barH = [math]::Max(1, $size * 0.055)
        $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 214, 40, 40))), ($size - $barW) / 2, $size * 0.7, $barW, $barH)
    }
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
