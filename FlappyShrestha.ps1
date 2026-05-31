Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$facePath = Join-Path $root "assets\shrestha-face.jpeg"
$iconPath = Join-Path $root "assets\flappy-shrestha.ico"
$crashPath = Join-Path $root "assets\crash-sound.mp4"
$musicPath = Join-Path $root "assets\bihari-phonk.mp3"

$faceImage = [System.Drawing.Image]::FromFile($facePath)
$faceCrop = New-Object System.Drawing.Rectangle 205, 480, 335, 355
$musicPlayer = $null
$crashPlayer = $null

if (Test-Path $musicPath) {
  try {
    $musicPlayer = New-Object -ComObject WMPlayer.OCX
    $musicPlayer.settings.autoStart = $false
    $musicPlayer.settings.volume = 45
    $musicPlayer.settings.setMode("loop", $true)
    $musicPlayer.URL = $musicPath
  } catch {
    $musicPlayer = $null
  }
}

if (Test-Path $crashPath) {
  try {
    $crashPlayer = New-Object -ComObject WMPlayer.OCX
    $crashPlayer.settings.autoStart = $false
    $crashPlayer.settings.volume = 100
    $crashPlayer.URL = $crashPath
  } catch {
    $crashPlayer = $null
  }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Flappy Shrestha"
$form.ClientSize = New-Object System.Drawing.Size 980, 720
$form.StartPosition = "CenterScreen"
$form.DoubleBuffered = $true
$paintStyles = [System.Windows.Forms.ControlStyles]::UserPaint -bor [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer
$setStyle = $form.GetType().GetMethod("SetStyle", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
$setStyle.Invoke($form, @($paintStyles, $true)) | Out-Null
$form.BackColor = [System.Drawing.Color]::FromArgb(114, 207, 255)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
if (Test-Path $iconPath) {
  $form.Icon = New-Object System.Drawing.Icon $iconPath
}

$state = @{
  Phase = "Ready"
  Score = 0
  Best = 0
  Pipes = New-Object System.Collections.ArrayList
  Clouds = New-Object System.Collections.ArrayList
  Particles = New-Object System.Collections.ArrayList
  GroundOffset = 0.0
  SpawnTimer = 0.0
  LastTick = [Environment]::TickCount
}

$player = @{
  X = 210.0
  Y = 300.0
  VY = 0.0
  Radius = 34.0
  Rotation = 0.0
}

$config = @{
  Gravity = 1180.0
  Flap = -420.0
  PipeWidth = 94.0
  PipeGap = 224.0
  PipeSpeed = 205.0
  PipeEvery = 1.55
  GroundHeight = 86.0
}

$gfx = @{
  CloudBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))
  PipeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(37, 132, 71))
  PipeShineBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(46, 255, 255, 255))
  PipePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(19, 87, 45)), 5
  GrassBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(111, 195, 95))
  DirtBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 166, 75))
  DarkGrassBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(67, 141, 66))
  GroundMarksBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(58, 112, 64, 32))
  ShadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(66, 23, 48, 29))
  WingBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 221, 86))
  BeakBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(242, 107, 79))
  HillBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 42, 115, 77))
  HudBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(145, 17, 32, 49))
  PanelBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(214, 17, 32, 49))
  ButtonBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 230, 92))
  WhiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
  MutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(234, 248, 255))
  DarkTextBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(23, 48, 29))
  TitleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 247, 191))
  SmallFont = New-Object System.Drawing.Font "Segoe UI", 9, ([System.Drawing.FontStyle]::Bold)
  ScoreFont = New-Object System.Drawing.Font "Segoe UI", 22, ([System.Drawing.FontStyle]::Bold)
  MainTitleFont = New-Object System.Drawing.Font "Segoe UI", 38, ([System.Drawing.FontStyle]::Bold)
  OverlayTitleFont = New-Object System.Drawing.Font "Segoe UI", 24, ([System.Drawing.FontStyle]::Bold)
  OverlayBodyFont = New-Object System.Drawing.Font "Segoe UI", 11, ([System.Drawing.FontStyle]::Regular)
  ButtonFont = New-Object System.Drawing.Font "Segoe UI", 12, ([System.Drawing.FontStyle]::Bold)
  CenterFormat = New-Object System.Drawing.StringFormat
}
$gfx.CenterFormat.Alignment = [System.Drawing.StringAlignment]::Center
$gfx.CenterFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

$random = New-Object System.Random

function Get-Rand([double]$min, [double]$max) {
  return $min + $random.NextDouble() * ($max - $min)
}

function Get-Clamped([double]$n, [double]$min, [double]$max) {
  return [Math]::Max($min, [Math]::Min($max, $n))
}

function Add-Clouds {
  $state.Clouds.Clear()
  for ($i = 0; $i -lt 8; $i++) {
    [void]$state.Clouds.Add([pscustomobject]@{
      X = Get-Rand 0 980
      Y = Get-Rand 86 310
      Scale = Get-Rand 0.75 1.55
      Speed = Get-Rand 10 24
    })
  }
}

function Add-Pipe([double]$extraX) {
  $floor = $form.ClientSize.Height - $config.GroundHeight
  $topLimit = 120.0
  $bottomLimit = $floor - 92.0
  [void]$state.Pipes.Add([pscustomobject]@{
    X = $form.ClientSize.Width + $extraX
    GapY = Get-Rand ($topLimit + $config.PipeGap / 2) ($bottomLimit - $config.PipeGap / 2)
    Passed = $false
  })
}

function Reset-Game {
  $state.Phase = "Playing"
  $state.Score = 0
  $state.SpawnTimer = 0.0
  $state.GroundOffset = 0.0
  $state.Pipes.Clear()
  $state.Particles.Clear()
  $player.X = [Math]::Min(210.0, $form.ClientSize.Width * 0.32)
  $player.Y = $form.ClientSize.Height * 0.42
  $player.VY = 0.0
  $player.Rotation = 0.0
  Add-Pipe 80
  Add-Pipe ($form.ClientSize.Width * 0.48)
}

function Start-Music {
  if ($null -ne $musicPlayer) {
    try {
      $musicPlayer.controls.play()
    } catch {}
  }
}

function Play-CrashSound {
  if ($null -ne $crashPlayer) {
    try {
      $crashPlayer.controls.stop()
      $crashPlayer.controls.currentPosition = 0
      $crashPlayer.controls.play()
    } catch {}
  }
}

function Start-Flap {
  if ($state.Phase -ne "Playing") {
    Reset-Game
    return
  }
  $player.VY = $config.Flap
  for ($i = 0; $i -lt 8; $i++) {
    [void]$state.Particles.Add([pscustomobject]@{
      X = $player.X - 22
      Y = $player.Y + (Get-Rand -12 18)
      VX = Get-Rand -150 -50
      VY = Get-Rand -40 70
      Life = Get-Rand 0.25 0.55
    })
  }
}

function Stop-Game {
  if ($state.Phase -eq "Over") {
    return
  }
  Play-CrashSound
  $state.Phase = "Over"
  if ($state.Score -gt $state.Best) {
    $state.Best = $state.Score
  }
}

function Update-Game([double]$dt) {
  $w = $form.ClientSize.Width
  $h = $form.ClientSize.Height
  $floor = $h - $config.GroundHeight

  foreach ($cloud in $state.Clouds) {
    $cloud.X -= $cloud.Speed * $dt
    if ($cloud.X -lt -150) {
      $cloud.X = $w + (Get-Rand 40 180)
      $cloud.Y = Get-Rand 86 310
    }
  }

  if ($state.Phase -ne "Playing") {
    return
  }

  $player.VY += $config.Gravity * $dt
  $player.Y += $player.VY * $dt
  $player.Rotation = Get-Clamped ($player.VY / 720.0) -0.55 1.05
  $state.SpawnTimer += $dt

  if ($state.SpawnTimer -ge $config.PipeEvery) {
    $state.SpawnTimer = 0.0
    Add-Pipe 0
  }

  $state.GroundOffset = ($state.GroundOffset + $config.PipeSpeed * $dt) % 64

  for ($i = $state.Pipes.Count - 1; $i -ge 0; $i--) {
    $pipe = $state.Pipes[$i]
    $pipe.X -= $config.PipeSpeed * $dt
    if (-not $pipe.Passed -and $pipe.X + $config.PipeWidth -lt $player.X - $player.Radius) {
      $pipe.Passed = $true
      $state.Score += 1
    }
    if ($pipe.X -lt -($config.PipeWidth + 12)) {
      $state.Pipes.RemoveAt($i)
    }
  }

  for ($i = $state.Particles.Count - 1; $i -ge 0; $i--) {
    $p = $state.Particles[$i]
    $p.X += $p.VX * $dt
    $p.Y += $p.VY * $dt
    $p.Life -= $dt
    if ($p.Life -le 0) {
      $state.Particles.RemoveAt($i)
    }
  }

  $hitFloor = $player.Y + $player.Radius -gt $floor
  $hitCeiling = $player.Y - $player.Radius -lt 0
  $hitPipe = $false
  foreach ($pipe in $state.Pipes) {
    $withinX = $player.X + $player.Radius * 0.74 -gt $pipe.X -and $player.X - $player.Radius * 0.74 -lt $pipe.X + $config.PipeWidth
    $outsideGap = $player.Y - $player.Radius * 0.74 -lt $pipe.GapY - $config.PipeGap / 2 -or $player.Y + $player.Radius * 0.74 -gt $pipe.GapY + $config.PipeGap / 2
    if ($withinX -and $outsideGap) {
      $hitPipe = $true
      break
    }
  }

  if ($hitFloor -or $hitCeiling -or $hitPipe) {
    Stop-Game
  }
}

function Draw-Cloud([System.Drawing.Graphics]$g, $cloud) {
  $g.TranslateTransform([single]$cloud.X, [single]$cloud.Y)
  $g.ScaleTransform([single]$cloud.Scale, [single]$cloud.Scale)
  $g.FillEllipse($gfx.CloudBrush, -24, -8, 48, 48)
  $g.FillEllipse($gfx.CloudBrush, -4, -28, 68, 68)
  $g.FillEllipse($gfx.CloudBrush, 42, -4, 56, 56)
  $g.FillRectangle($gfx.CloudBrush, 0, 18, 84, 30)
  $g.ResetTransform()
}

function Draw-Pipe([System.Drawing.Graphics]$g, $pipe) {
  $floor = $form.ClientSize.Height - $config.GroundHeight
  $topBottom = $pipe.GapY - $config.PipeGap / 2
  $bottomTop = $pipe.GapY + $config.PipeGap / 2

  $g.FillRectangle($gfx.PipeBrush, [single]$pipe.X, -10, [single]$config.PipeWidth, [single]($topBottom + 10))
  $g.DrawRectangle($gfx.PipePen, [single]$pipe.X, -10, [single]$config.PipeWidth, [single]($topBottom + 10))
  $g.FillRectangle($gfx.PipeBrush, [single]($pipe.X - 10), [single]($topBottom - 28), [single]($config.PipeWidth + 20), 30)
  $g.DrawRectangle($gfx.PipePen, [single]($pipe.X - 10), [single]($topBottom - 28), [single]($config.PipeWidth + 20), 30)

  $g.FillRectangle($gfx.PipeBrush, [single]$pipe.X, [single]$bottomTop, [single]$config.PipeWidth, [single]($floor - $bottomTop))
  $g.DrawRectangle($gfx.PipePen, [single]$pipe.X, [single]$bottomTop, [single]$config.PipeWidth, [single]($floor - $bottomTop))
  $g.FillRectangle($gfx.PipeBrush, [single]($pipe.X - 10), [single]$bottomTop, [single]($config.PipeWidth + 20), 30)
  $g.DrawRectangle($gfx.PipePen, [single]($pipe.X - 10), [single]$bottomTop, [single]($config.PipeWidth + 20), 30)

  $g.FillRectangle($gfx.PipeShineBrush, [single]($pipe.X + 14), 0, 12, [single]([Math]::Max(0, $topBottom - 36)))
  $g.FillRectangle($gfx.PipeShineBrush, [single]($pipe.X + 14), [single]($bottomTop + 34), 12, [single]([Math]::Max(0, $floor - $bottomTop - 38)))
}

function Draw-Ground([System.Drawing.Graphics]$g) {
  $w = $form.ClientSize.Width
  $h = $form.ClientSize.Height
  $y = $h - $config.GroundHeight
  $g.FillRectangle($gfx.GrassBrush, 0, [single]$y, $w, [single]$config.GroundHeight)
  $g.FillRectangle($gfx.DirtBrush, 0, [single]($y + 22), $w, [single]($config.GroundHeight - 22))
  for ($x = -64 - $state.GroundOffset; $x -lt $w + 70; $x += 64) {
    $g.FillRectangle($gfx.DarkGrassBrush, [single]$x, [single]($y + 8), 42, 12)
    $g.FillRectangle($gfx.GroundMarksBrush, [single]($x + 18), [single]($y + 40), 34, 10)
  }
}

function Draw-Player([System.Drawing.Graphics]$g) {
  $g.TranslateTransform([single]$player.X, [single]$player.Y)
  $g.RotateTransform([single]($player.Rotation * 57.2958))

  $g.FillEllipse($gfx.ShadowBrush, 6, 39, 64, 20)

  $wingPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $wingPath.AddBezier(-28, 4, -52, 7, -67, -12, -54, -30)
  $wingPath.AddBezier(-54, -30, -34, -22, -24, -13, -18, -8)
  $wingPath.CloseFigure()
  $g.FillPath($gfx.WingBrush, $wingPath)

  $oldClip = $g.Clip
  $facePathClip = New-Object System.Drawing.Drawing2D.GraphicsPath
  $facePathClip.AddEllipse(-$player.Radius, -$player.Radius, $player.Radius * 2, $player.Radius * 2)
  $g.SetClip($facePathClip)
  $dest = New-Object System.Drawing.RectangleF (-$player.Radius), (-$player.Radius), ($player.Radius * 2), ($player.Radius * 2)
  $g.DrawImage($faceImage, $dest, $faceCrop, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Clip = $oldClip

  $beakPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $beakPath.AddPolygon([System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF ([single]($player.Radius - 2), -3)),
    (New-Object System.Drawing.PointF ([single]($player.Radius + 24), 7)),
    (New-Object System.Drawing.PointF ([single]($player.Radius - 2), 18))
  ))
  $g.FillPath($gfx.BeakBrush, $beakPath)

  $oldClip.Dispose()
  $facePathClip.Dispose()
  $wingPath.Dispose()
  $beakPath.Dispose()
  $g.ResetTransform()
}

function Draw-Overlay([System.Drawing.Graphics]$g) {
  if ($state.Phase -eq "Playing") {
    return
  }

  $w = $form.ClientSize.Width
  $h = $form.ClientSize.Height
  $panel = New-Object System.Drawing.RectangleF (($w - 360) / 2), (($h - 184) / 2), 360, 184

  $g.FillRectangle($gfx.PanelBrush, $panel)
  $title = if ($state.Phase -eq "Ready") { "Flappy Shrestha" } else { "Game Over" }
  $body = if ($state.Phase -eq "Ready") { "Press space, click, or tap to flap through the gaps." } else { "Score: $($state.Score). Best: $($state.Best). Press space, click, or tap to try again." }
  $buttonText = if ($state.Phase -eq "Ready") { "Start Game" } else { "Restart" }
  $g.DrawString($title, $gfx.OverlayTitleFont, $gfx.WhiteBrush, (New-Object System.Drawing.RectangleF $panel.X, ($panel.Y + 24), $panel.Width, 44), $gfx.CenterFormat)
  $g.DrawString($body, $gfx.OverlayBodyFont, $gfx.MutedBrush, (New-Object System.Drawing.RectangleF ($panel.X + 28), ($panel.Y + 74), ($panel.Width - 56), 46), $gfx.CenterFormat)
  $buttonRect = New-Object System.Drawing.RectangleF (($w - 142) / 2), ($panel.Y + 126), 142, 46
  $g.FillRectangle($gfx.ButtonBrush, $buttonRect)
  $g.DrawString($buttonText, $gfx.ButtonFont, $gfx.DarkTextBrush, $buttonRect, $gfx.CenterFormat)
}

$form.Add_Paint({
  param($sender, $event)
  $g = $event.Graphics
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $w = $form.ClientSize.Width
  $h = $form.ClientSize.Height

  $sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0 0), (New-Object System.Drawing.Point 0 $h), ([System.Drawing.Color]::FromArgb(114, 207, 255)), ([System.Drawing.Color]::FromArgb(199, 244, 255))
  $g.FillRectangle($sky, 0, 0, $w, $h)
  $sky.Dispose()

  foreach ($cloud in $state.Clouds) {
    Draw-Cloud $g $cloud
  }

  for ($x = -80; $x -lt $w + 120; $x += 160) {
    $hill = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hill.AddPolygon([System.Drawing.PointF[]]@(
      (New-Object System.Drawing.PointF ([single]$x), [single]($h - $config.GroundHeight)),
      (New-Object System.Drawing.PointF ([single]($x + 82)), [single]($h - 220)),
      (New-Object System.Drawing.PointF ([single]($x + 170)), [single]($h - $config.GroundHeight))
    ))
    $g.FillPath($gfx.HillBrush, $hill)
    $hill.Dispose()
  }

  foreach ($p in $state.Particles) {
    $spark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb([int](Get-Clamped ($p.Life * 610) 0 255), 255, 242, 167))
    $g.FillEllipse($spark, [single]$p.X, [single]$p.Y, 10, 10)
    $spark.Dispose()
  }

  foreach ($pipe in $state.Pipes) {
    Draw-Pipe $g $pipe
  }

  Draw-Ground $g
  Draw-Player $g

  $g.FillRectangle($gfx.HudBrush, 14, 14, 92, 60)
  $g.FillRectangle($gfx.HudBrush, ($w - 106), 14, 92, 60)
  $g.DrawString("SCORE", $gfx.SmallFont, $gfx.WhiteBrush, (New-Object System.Drawing.RectangleF 14, 18, 92, 18), $gfx.CenterFormat)
  $g.DrawString([string]$state.Score, $gfx.ScoreFont, $gfx.WhiteBrush, (New-Object System.Drawing.RectangleF 14, 34, 92, 34), $gfx.CenterFormat)
  $g.DrawString("BEST", $gfx.SmallFont, $gfx.WhiteBrush, (New-Object System.Drawing.RectangleF ($w - 106), 18, 92, 18), $gfx.CenterFormat)
  $g.DrawString([string]([Math]::Max($state.Best, $state.Score)), $gfx.ScoreFont, $gfx.WhiteBrush, (New-Object System.Drawing.RectangleF ($w - 106), 34, 92, 34), $gfx.CenterFormat)
  $g.DrawString("Flappy Shrestha", $gfx.MainTitleFont, $gfx.TitleBrush, (New-Object System.Drawing.RectangleF 150, 18, ($w - 300), 60), $gfx.CenterFormat)

  Draw-Overlay $g
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 16
$timer.Add_Tick({
  $now = [Environment]::TickCount
  $dt = [Math]::Min(0.033, ($now - $state.LastTick) / 1000.0)
  $state.LastTick = $now
  Update-Game $dt
  $form.Invalidate()
})

$form.Add_KeyDown({
  param($sender, $event)
  if ($event.KeyCode -eq [System.Windows.Forms.Keys]::Space -or $event.KeyCode -eq [System.Windows.Forms.Keys]::Up -or $event.KeyCode -eq [System.Windows.Forms.Keys]::W) {
    Start-Flap
    $event.SuppressKeyPress = $true
  }
  if ($event.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
    $form.Close()
  }
})

$form.Add_MouseDown({ Start-Flap })
$form.Add_FormClosed({
  $timer.Stop()
  if ($null -ne $musicPlayer) {
    try {
      $musicPlayer.controls.stop()
      $musicPlayer.close()
    } catch {}
  }
  if ($null -ne $crashPlayer) {
    try {
      $crashPlayer.controls.stop()
      $crashPlayer.close()
    } catch {}
  }
  $timer.Dispose()
  foreach ($resource in $gfx.Values) {
    if ($resource -is [System.IDisposable]) {
      $resource.Dispose()
    }
  }
  $faceImage.Dispose()
})

Add-Clouds
Start-Music
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
