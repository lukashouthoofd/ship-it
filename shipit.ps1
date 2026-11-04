# Ship It overlay: flashes "SHIP IIIIITTTT" on every monitor for ~2.2 s.
# Click-through, never takes focus, one instance at a time. Errors go to shipit.log (git-ignored).
$ErrorActionPreference = 'Stop'
$logFile = Join-Path $PSScriptRoot 'shipit.log'
function Log($msg) {
  try {
    if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 256KB) { Remove-Item $logFile -Force }
    Add-Content -Path $logFile -Value ('{0:yyyy-MM-dd HH:mm:ss.fff} [{1}] {2}' -f (Get-Date), $PID, $msg)
  } catch {}
}

$mutex = $null; $owned = $false
try {
  # one overlay at a time (the local hook and the GitHub watcher can both fire for one merge).
  # The OS releases a mutex when its owner dies; an abandoned one is simply taken over.
  $mutex = New-Object System.Threading.Mutex($false, 'Local\ShipItOverlay')
  try { $owned = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
  if (-not $owned) { Log 'another overlay is already showing, skipping'; exit 0 }

  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  if (-not ('ShipItOverlay' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ShipItOverlay : Form {
  [DllImport("user32.dll")] static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);

  const int WS_EX_TOPMOST = 0x8, WS_EX_TRANSPARENT = 0x20, WS_EX_TOOLWINDOW = 0x80,
            WS_EX_LAYERED = 0x80000, WS_EX_NOACTIVATE = 0x8000000;

  // physical pixels, so each form really covers its whole (scaled) monitor
  public static void MakeDpiAware() {
    try { if (SetProcessDpiAwarenessContext(new IntPtr(-4))) return; } catch { }
    try { SetProcessDPIAware(); } catch { }
  }

  readonly string text;
  readonly Rectangle area;

  public ShipItOverlay(Rectangle bounds, string text) {
    this.text = text; area = bounds;
    FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false; BackColor = Color.Black; DoubleBuffered = true; Bounds = bounds;
  }

  // Styles are set at creation time (not patched later with SetWindowLong), so WinForms
  // can never recreate the handle without them. Alpha is driven via SetLayeredWindowAttributes
  // directly; Form.Opacity is not used because its setter rewrites the extended style.
  protected override CreateParams CreateParams {
    get {
      CreateParams cp = base.CreateParams;
      cp.ExStyle |= WS_EX_TOPMOST | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE;
      return cp;
    }
  }
  protected override bool ShowWithoutActivation { get { return true; } }

  protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); SetAlpha(0); }

  public void SetAlpha(double a) {
    if (!IsHandleCreated) return;
    SetLayeredWindowAttributes(Handle, 0, (byte)Math.Round(Math.Max(0, Math.Min(1, a)) * 255), 2 /*LWA_ALPHA*/);
  }

  public void PinOnTop() {
    // HWND_TOPMOST, SWP_NOACTIVATE | SWP_SHOWWINDOW
    SetWindowPos(Handle, new IntPtr(-1), area.X, area.Y, area.Width, area.Height, 0x10 | 0x40);
  }

  protected override void OnPaint(PaintEventArgs pe) {
    Graphics g = pe.Graphics;
    g.TextRenderingHint = TextRenderingHint.AntiAlias;
    int w = ClientSize.Width, h = ClientSize.Height;
    SizeF sz;
    using (Font probe = new Font("Impact", 100, FontStyle.Bold, GraphicsUnit.Pixel)) sz = g.MeasureString(text, probe);
    float scale = Math.Min(w * 0.94f / sz.Width, h * 0.6f / sz.Height);
    using (Font font = new Font("Impact", Math.Max(8f, 100 * scale), FontStyle.Bold, GraphicsUnit.Pixel)) {
      sz = g.MeasureString(text, font);
      float x = (w - sz.Width) / 2, y = (h - sz.Height) / 2;
      float shadow = Math.Max(4f, h / 130f);
      g.DrawString(text, font, Brushes.DimGray, x + shadow, y + shadow);
      g.DrawString(text, font, Brushes.Lime, x, y);
    }
  }

  public static string Error;
  public static List<string> Info = new List<string>();

  // Shows one overlay per screen, fades in/out, returns after totalMs.
  public static void Run(string text, int totalMs, int fadeMs, double peak) {
    // hard cap: whatever happens, this process never outlives the flash for long
    System.Threading.Timer killer = new System.Threading.Timer(delegate { Environment.Exit(3); }, null, totalMs + 8000, System.Threading.Timeout.Infinite);
    List<ShipItOverlay> forms = new List<ShipItOverlay>();
    foreach (Screen s in Screen.AllScreens) {
      ShipItOverlay f = new ShipItOverlay(s.Bounds, text);
      f.Show(); f.PinOnTop(); forms.Add(f);
      Info.Add(s.DeviceName + " " + s.Bounds);
    }
    Stopwatch sw = Stopwatch.StartNew();
    Timer timer = new Timer();
    timer.Interval = 15;
    timer.Tick += delegate {
      try {
        long t = sw.ElapsedMilliseconds;
        if (t >= totalMs) {
          timer.Stop();
          foreach (ShipItOverlay f in forms) f.Close();
          Application.ExitThread();
          return;
        }
        double o = peak;
        if (t < fadeMs) o = peak * t / fadeMs;
        else if (t > totalMs - fadeMs) o = peak * (totalMs - t) / fadeMs;
        foreach (ShipItOverlay f in forms) f.SetAlpha(o);
      } catch (Exception ex) {
        Error = ex.ToString(); timer.Stop(); Application.ExitThread();
      }
    };
    timer.Start();
    Application.Run();
    killer.Dispose();
  }
}
'@
  }

  [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::ThrowException)
  [ShipItOverlay]::MakeDpiAware()

  $total = 2200
  $player = $null
  $mp3 = Join-Path $PSScriptRoot 'shipit.mp3'
  if (Test-Path $mp3) {
    try {
      Add-Type -AssemblyName PresentationCore
      $player = New-Object System.Windows.Media.MediaPlayer
      $player.Open([Uri]$mp3); $player.Volume = 1.0
      for ($i = 0; $i -lt 50 -and -not $player.NaturalDuration.HasTimeSpan; $i++) {
        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 20
      }
      if ($player.NaturalDuration.HasTimeSpan) {
        $total = [int][Math]::Min(8000, [Math]::Max(2200, $player.NaturalDuration.TimeSpan.TotalMilliseconds))
      }
      $player.Play()
    } catch { Log "sound failed: $($_.Exception.Message)"; $player = $null }
  }

  [ShipItOverlay]::Run('SHIP IIIIITTTT', $total, 250, 0.88)
  if ([ShipItOverlay]::Error) { Log "overlay error: $([ShipItOverlay]::Error)" }
  else { Log "shown ${total}ms on $([ShipItOverlay]::Info -join '; ')" }
  if ($player) { $player.Stop(); $player.Close() }
} catch {
  Log "ERROR: $($_.Exception.GetType().FullName): $($_.Exception.Message) $($_.InvocationInfo.PositionMessage)"
} finally {
  if ($owned) { try { $mutex.ReleaseMutex() } catch {} }
  if ($mutex) { $mutex.Dispose() }
}
