Add-Type -AssemblyName System.Drawing
$outputPath = Join-Path $PSScriptRoot 'index/team-slot-landscape.png'
$bmp = [System.Drawing.Bitmap]::new(840,400)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$path.AddPolygon([System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(28,14),[System.Drawing.PointF]::new(792,14),
    [System.Drawing.PointF]::new(824,44),[System.Drawing.PointF]::new(824,354),
    [System.Drawing.PointF]::new(792,386),[System.Drawing.PointF]::new(44,386),
    [System.Drawing.PointF]::new(16,358),[System.Drawing.PointF]::new(16,30)))
foreach ($layer in @(@(26,12),@(18,18),@(10,35))) {
    $halo = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($layer[1],210,225,255),$layer[0])
    $g.DrawPath($halo,$path)
    $halo.Dispose()
}
$rect = [System.Drawing.Rectangle]::new(0,0,840,400)
$fill = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect,[System.Drawing.Color]::FromArgb(35,41,55),[System.Drawing.Color]::FromArgb(8,12,23),90)
$g.FillPath($fill,$path)
$g.SetClip($path)
$dot = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(28,205,220,245))
for ($x=34; $x -lt 820; $x+=24) {
    for ($y=30; $y -lt 384; $y+=24) { $g.FillEllipse($dot,$x,$y,5,5) }
}
$sheen = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(26,235,240,255))
$g.FillPolygon($sheen,[System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(14,14),[System.Drawing.PointF]::new(470,14),
    [System.Drawing.PointF]::new(14,268)))
$g.ResetClip()
$ink = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(4,6,17),10)
$g.DrawPath($ink,$path)
$edge = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(215,230,245),4)
$g.DrawPath($edge,$path)
$bmp.Save($outputPath,[System.Drawing.Imaging.ImageFormat]::Png)
foreach ($item in @($edge,$ink,$sheen,$dot,$fill,$path,$g,$bmp)) { $item.Dispose() }
Write-Output $outputPath
