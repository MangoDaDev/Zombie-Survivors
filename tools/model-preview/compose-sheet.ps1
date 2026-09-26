param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$layout = Get-Content -LiteralPath (Join-Path $Directory 'contact-layout.json') -Raw | ConvertFrom-Json
$bitmap = New-Object System.Drawing.Bitmap ([int]$layout.width), ([int]$layout.height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#111A26'))
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$titleFont = New-Object System.Drawing.Font 'Segoe UI', 21, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$font = New-Object System.Drawing.Font 'Segoe UI', 14, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$small = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$white = [System.Drawing.Brushes]::White
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#B8C6D8'))
try {
    $titleRectangle = New-Object System.Drawing.RectangleF 20, 14, ([single]($layout.width-40)), 32
    $titleFormat = New-Object System.Drawing.StringFormat
    $titleFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    try { $graphics.DrawString([string]$layout.title, $titleFont, $white, $titleRectangle, $titleFormat) } finally { $titleFormat.Dispose() }
    $graphics.DrawString([string]$layout.dimensions, $font, $muted, 20, 50)
    foreach ($panel in $layout.panels) {
        $graphics.DrawString([string]$panel.name, $font, $white, [single]($panel.x+14), [single]($panel.y+6))
        $rectangle = New-Object System.Drawing.RectangleF ([single]$panel.left), ([single]$panel.top), ([single]$panel.width), ([single]$panel.height)
        $image = [System.Drawing.Image]::FromFile((Join-Path $Directory $panel.file))
        try { $graphics.DrawImage($image, $rectangle) } finally { $image.Dispose() }
        $state = $graphics.Save()
        $graphics.SetClip($rectangle)
        foreach ($line in $panel.lines) {
            $pen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($line.color)), 1.5
            try {
                if ($line.dashed) { $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
                $graphics.DrawLine($pen, [single]$line.a[0], [single]$line.a[1], [single]$line.b[0], [single]$line.b[1])
            } finally { $pen.Dispose() }
        }
        $pivotPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Magenta), 2
        try { $graphics.DrawEllipse($pivotPen, [single]($panel.pivot[0]-4), [single]($panel.pivot[1]-4), 8, 8) } finally { $pivotPen.Dispose() }
        $graphics.Restore($state)
        $barY = [single]($panel.y+426)
        $graphics.DrawLine([System.Drawing.Pens]::White, [single]($panel.x+14), $barY, [single]($panel.x+14+$panel.scaleLength), $barY)
        $graphics.DrawString([string]$panel.scaleLabel, $small, $muted, [single]($panel.x+14), [single]($barY-19))
    }
    for ($i=0; $i -lt $layout.footer.Count; $i++) {
        $footerHeight = if ($layout.footerHeight) { $layout.footerHeight } else { 90 }
        $lineHeight = [single](($footerHeight-24)/$layout.footer.Count)
        $footerRectangle = New-Object System.Drawing.RectangleF 20, ([single]($layout.height-$footerHeight+12+$i*$lineHeight)), ([single]($layout.width-40)), $lineHeight
        $graphics.DrawString([string]$layout.footer[$i], $small, $muted, $footerRectangle)
    }
    $bitmap.Save((Join-Path $Directory 'contact-sheet.png'), [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose(); $bitmap.Dispose(); $titleFont.Dispose(); $font.Dispose(); $small.Dispose(); $muted.Dispose()
}
