# one overlay at a time (the local hook and the GitHub watcher can both fire for one merge)
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ShipItOverlay', [ref]$created)
if (-not $created) { exit }
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, PresentationCore
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class W { [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int i);
 [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h,int i,int v); }
"@
$text = 'SHIP IIIIITTTT'
$forms = @()
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
  $f = New-Object System.Windows.Forms.Form
  $f.FormBorderStyle = 'None'; $f.StartPosition = 'Manual'; $f.ShowInTaskbar = $false
  $f.TopMost = $true; $f.Bounds = $s.Bounds; $f.BackColor = [System.Drawing.Color]::Black
  $f.Opacity = 0
  $b = $s.Bounds
  $f.Add_Paint({
    param($sender, $pe)
    $g = $pe.Graphics; $g.TextRenderingHint = 'AntiAliasGridFit'
    $w = $sender.ClientSize.Width; $h = $sender.ClientSize.Height
    $font = New-Object System.Drawing.Font('Impact', 100, [System.Drawing.FontStyle]::Bold)
    $sz = $g.MeasureString($text, $font)
    $scale = [Math]::Min(($w * 0.94) / $sz.Width, ($h * 0.6) / $sz.Height)
    $font = New-Object System.Drawing.Font('Impact', [single](100 * $scale), [System.Drawing.FontStyle]::Bold)
    $sz = $g.MeasureString($text, $font)
    $x = ($w - $sz.Width) / 2; $y = ($h - $sz.Height) / 2
    $g.DrawString($text, $font, [System.Drawing.Brushes]::DimGray, $x + 8, $y + 8)
    $g.DrawString($text, $font, [System.Drawing.Brushes]::Lime, $x, $y)
  })
  $f.Add_Shown({
    # click-through, no focus steal, hidden from alt-tab
    $st = [W]::GetWindowLong($this.Handle, -20)
    [void][W]::SetWindowLong($this.Handle, -20, ($st -bor 0x80020 -bor 0x08000000 -bor 0x80))
  })
  $f.Show(); $forms += $f
}
$mp3 = Join-Path $PSScriptRoot 'shipit.mp3'
$player = $null
if (Test-Path $mp3) {
  $player = New-Object System.Windows.Media.MediaPlayer
  $player.Open([Uri]$mp3); $player.Volume = 1.0; $player.Play()
}
$sw = [Diagnostics.Stopwatch]::StartNew()
$total = 2200
if ($player) { for ($i=0; $i -lt 50 -and -not $player.NaturalDuration.HasTimeSpan; $i++) { Start-Sleep -Milliseconds 20 }; if ($player.NaturalDuration.HasTimeSpan) { $total = [Math]::Min(8000, [Math]::Max(2200, [int]$player.NaturalDuration.TimeSpan.TotalMilliseconds)) } }
$sw.Restart(); $fade = 250
while ($sw.ElapsedMilliseconds -lt $total) {
  $t = $sw.ElapsedMilliseconds
  $o = 0.88
  if ($t -lt $fade) { $o = 0.88 * $t / $fade } elseif ($t -gt $total - $fade) { $o = 0.88 * ($total - $t) / $fade }
  foreach ($f in $forms) { $f.Opacity = [Math]::Max(0, $o) }
  [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 16
}
foreach ($f in $forms) { $f.Close() }
if ($player) { $player.Stop(); $player.Close() }
