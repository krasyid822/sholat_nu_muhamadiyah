# PowerShell script to update Flutter Web icons using the generated premium app icon
Add-Type -AssemblyName System.Drawing

$inputPath = "$PSScriptRoot\app_icon_exact.png"
$webDir = "$PSScriptRoot\..\web"

function Resize-Image {
    param (
        [string]$InputPath,
        [string]$OutputPath,
        [int]$Width,
        [int]$Height
    )
    Write-Host "Resizing to $Width x $Height -> $OutputPath"
    $img = [System.Drawing.Image]::FromFile($InputPath)
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $graph = [System.Drawing.Graphics]::FromImage($bmp)
    
    # High-quality rendering settings
    $graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graph.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graph.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    
    $graph.DrawImage($img, 0, 0, $Width, $Height)
    
    # Save as PNG
    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    # Dispose resources
    $graph.Dispose()
    $bmp.Dispose()
    $img.Dispose()
}

# Create icons directory if it doesn't exist
$iconsDir = Join-Path $webDir "icons"
if (-not (Test-Path $iconsDir)) {
    New-Item -ItemType Directory -Path $iconsDir -Force
}

# Update Favicon (32x32)
Resize-Image -InputPath $inputPath -OutputPath (Join-Path $webDir "favicon.png") -Width 32 -Height 32

# Update Standard Web Icons
Resize-Image -InputPath $inputPath -OutputPath (Join-Path $iconsDir "Icon-192.png") -Width 192 -Height 192
Resize-Image -InputPath $inputPath -OutputPath (Join-Path $iconsDir "Icon-512.png") -Width 512 -Height 512

# Update Maskable Web Icons (usually same size but with safe margins, we can use the same high-quality icon)
Resize-Image -InputPath $inputPath -OutputPath (Join-Path $iconsDir "Icon-maskable-192.png") -Width 192 -Height 192
Resize-Image -InputPath $inputPath -OutputPath (Join-Path $iconsDir "Icon-maskable-512.png") -Width 512 -Height 512

Write-Host "Successfully updated all web icons and favicon with the premium Al-Waqt design!"
