# PowerShell script to draw the exact CSS splash screen moon spinner icon natively using .NET System.Drawing
Add-Type -AssemblyName System.Drawing

$outputPath = "$PSScriptRoot\app_icon_exact.png"
$webDir = "$PSScriptRoot\..\web"

# Create a 512x512 high-resolution bitmap
$bmp = New-Object System.Drawing.Bitmap 512, 512
$graph = [System.Drawing.Graphics]::FromImage($bmp)

# Set high-quality rendering options
$graph.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graph.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# 1. Background is left transparent by default (no FillRectangle).

# 2. Draw Outer Glow (corresponds to CSS box-shadow: 0 0 20px rgba(212, 175, 55, 0.4))
# Glow bounding box: diameter 420px, centered at 256, 256 (offset X/Y = 256 - 210 = 46)
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(46, 46, 420, 420)
$glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
$glowBrush.CenterPoint = New-Object System.Drawing.PointF 256, 256
$glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(130, 212, 175, 55) # Golden glow with 0.5 opacity (130/255)
$glowBrush.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 212, 175, 55)) # Transparent outer edge
$graph.FillPath($glowBrush, $glowPath)

# 3. Draw Base Golden Circle (corresponds to .moon-spinner base with radial-gradient)
# Base circle bounding box: diameter 300px, centered at 256, 256 (offset X/Y = 256 - 150 = 106)
$basePath = New-Object System.Drawing.Drawing2D.GraphicsPath
$basePath.AddEllipse(106, 106, 300, 300)
$baseBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $basePath

# Radial gradient: center at 30% X and 30% Y relative to the circle (so 106 + 300*0.3 = 196, 106 + 300*0.3 = 196)
$baseBrush.CenterPoint = New-Object System.Drawing.PointF 196, 196
$baseBrush.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 224, 130) # #FFE082
$baseBrush.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(255, 212, 175, 55)) # #D4AF37
$graph.FillPath($baseBrush, $basePath)

# 4. Draw Mask Circle (corresponds to ::after pseudo-element offset right/top to form the crescent)
# Scaled offset from CSS right: -12px, top: -1px (with 300/70 scale: dx = 12 * 4.2857 = 51px, dy = -1 * 4.2857 = -4px)
# Center X = 256 + 51 = 307. Center Y = 256 - 4 = 252.
# Bounding box: X = 307 - 150 = 157, Y = 252 - 150 = 102. Diameter = 300px.
$maskPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$maskPath.AddEllipse(157, 102, 300, 300)

# Set compositing mode to SourceCopy to act as an eraser
$graph.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$eraseBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Transparent)
$graph.FillPath($eraseBrush, $maskPath)
$eraseBrush.Dispose()

# Save the master high-resolution icon
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up resources
$glowBrush.Dispose()
$glowPath.Dispose()
$baseBrush.Dispose()
$basePath.Dispose()
$maskPath.Dispose()
$graph.Dispose()
$bmp.Dispose()

Write-Host "Perfectly rendered exact CSS splashscreen moon icon at $outputPath"
