<#
.SYNOPSIS
    Cong cu tu dong toi uu hoa va resize hinh anh cho Harbin 2027.
    Chay truc tiep bang PowerShell tren Windows ma khong can cai them bat ky phan mem nao.

.DESCRIPTION
    Quet cac thu muc:
    - images/activities/  (Toi uu do phan giai toi da 1200px chieu ngang)
    - images/concepts/    (Toi uu do phan giai toi da 800px chieu ngang)
    - images/outfits/     (Toi uu do phan giai toi da 800px chieu ngang)

    Tu dong resize bang thuat toan HighQualityBicubic, nen JPEG muc 82%
    giup giam 70-90% dung luong file nhung van giu nguyen do sac net hoan hao!
#>

param(
    [int]$MaxActivityWidth = 1200,
    [int]$MaxConceptWidth = 800,
    [int]$MaxOutfitWidth = 800,
    [int]$Quality = 82,
    [switch]$Force
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path -Parent $scriptRoot
$imagesDir = Join-Path $repoRoot "images"

if (-not (Test-Path $imagesDir)) {
    Write-Host "[!] Khong tim thay thu muc: $imagesDir" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   HARBIN 2027 - IMAGE RESIZER & OPTIMIZATION TOOL        " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Thu muc goc: $imagesDir" -ForegroundColor Gray
Write-Host "Chat luong JPEG: $Quality%" -ForegroundColor Gray
Write-Host ""

$targets = @(
    @{ Folder = "activities"; MaxWidth = $MaxActivityWidth },
    @{ Folder = "concepts";   MaxWidth = $MaxConceptWidth },
    @{ Folder = "outfits";    MaxWidth = $MaxOutfitWidth }
)

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageDecoders() | Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$totalFiles = 0
$optimizedCount = 0
$totalSavedBytes = 0

foreach ($t in $targets) {
    $folderPath = Join-Path $imagesDir $t.Folder
    if (-not (Test-Path $folderPath)) { continue }

    $files = Get-ChildItem -Path $folderPath -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png)$' }
    if ($files.Count -eq 0) { continue }

    Write-Host "[>] Dang xu ly thu muc: $($t.Folder)/ (Max Width: $($t.MaxWidth)px)" -ForegroundColor Green

    foreach ($f in $files) {
        $totalFiles++
        $filePath = $f.FullName
        $origSize = $f.Length

        try {
            $srcImg = [System.Drawing.Image]::FromFile($filePath)
            $origWidth = $srcImg.Width
            $origHeight = $srcImg.Height

            $needsResize = ($origWidth -gt $t.MaxWidth) -or ($f.Extension -eq ".png") -or $Force

            if (-not $needsResize -and $origSize -lt 300KB) {
                Write-Host "  [-] $($f.Name): Da toi uu roi ($($origWidth)x$($origHeight), $([Math]::Round($origSize/1KB, 1)) KB) - Bo qua." -ForegroundColor DarkGray
                $srcImg.Dispose()
                continue
            }

            # Tinh toan kich thuoc moi
            if ($origWidth -gt $t.MaxWidth) {
                $newWidth = $t.MaxWidth
                $newHeight = [int][Math]::Round($origHeight * ($t.MaxWidth / $origWidth))
            } else {
                $newWidth = $origWidth
                $newHeight = $origHeight
            }

            $destBmp = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
            $graphics = [System.Drawing.Graphics]::FromImage($destBmp)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

            $graphics.DrawImage($srcImg, 0, 0, $newWidth, $newHeight)

            $srcImg.Dispose()

            # Luu ra file tam roi ghi de
            $tempPath = $filePath + ".tmp.jpg"
            $destBmp.Save($tempPath, $jpegCodec, $encoderParams)

            $graphics.Dispose()
            $destBmp.Dispose()

            $newSize = (Get-Item $tempPath).Length

            # Neu doi extension tu png sang jpg thi doi ten goc
            $finalPath = [System.IO.Path]::ChangeExtension($filePath, ".jpg")
            if (Test-Path $filePath) { Remove-Item $filePath -Force }
            Move-Item $tempPath $finalPath -Force

            $savedBytes = $origSize - $newSize
            if ($savedBytes -gt 0) {
                $totalSavedBytes += $savedBytes
            }
            $optimizedCount++

            $pct = if ($origSize -gt 0) { [Math]::Round(($origSize - $newSize) / $origSize * 100, 1) } else { 0 }
            Write-Host "  [OK] $($f.Name) -> $($origWidth)x$($origHeight) ($([Math]::Round($origSize/1KB, 1)) KB) ==> $($newWidth)x$($newHeight) ($([Math]::Round($newSize/1KB, 1)) KB) | Giam: $pct%" -ForegroundColor Cyan
        }
        catch {
            Write-Host "  [X] Loi khi xu ly $($f.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   HOAN THANH TOI UU HOA HINH ANH!                        " -ForegroundColor Yellow
Write-Host "   - Tong so file da quet: $totalFiles" -ForegroundColor White
Write-Host "   - So file da toi uu:   $optimizedCount" -ForegroundColor White
Write-Host "   - Dung luong tiet kiem: $([Math]::Round($totalSavedBytes / 1MB, 2)) MB" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
