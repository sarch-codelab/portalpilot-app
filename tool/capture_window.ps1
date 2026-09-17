param([string]$Out = "compilaciones/preview/app_01.png")
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinCap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[WinCap]::SetProcessDPIAware() | Out-Null
$proc = Get-Process PortalPilotWorkspace -ErrorAction Stop
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "NO_WINDOW"; exit 1 }
[WinCap]::ShowWindow($hwnd, 3) | Out-Null
[WinCap]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 1000

$rect = New-Object WinCap+RECT
[WinCap]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) { Write-Output "BAD_RECT"; exit 1 }

# Intento 1: PrintWindow (captura directa del contenido de la ventana, incluso parcialmente tapada)
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
# PW_RENDERFULLCONTENT = 2 (incluye contenido GPU/DirectX)
$ok = [WinCap]::PrintWindow($hwnd, $hdc, 2)
$g.ReleaseHdc($hdc)
$g.Dispose()

# Verificar diversidad de color
$colors = New-Object System.Collections.Generic.HashSet[string]
for ($x = 0; $x -lt $w; $x += 30) {
  for ($y = 0; $y -lt $h; $y += 30) {
    $c = $bmp.GetPixel($x, $y); [void]$colors.Add("$($c.R),$($c.G),$($c.B)")
  }
}
if ($ok -and $colors.Count -gt 10) {
  $bmp.Save($Out); $bmp.Dispose()
  Write-Output "OK_PRINTWINDOW ${w}x${h} colores=$($colors.Count)"
  exit 0
}

# Intento 2: CopyFromScreen con coordenadas físicas
$g2 = [System.Drawing.Graphics]::FromImage($bmp)
$g2.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$g2.Dispose()
$colors.Clear()
for ($x = 0; $x -lt $w; $x += 30) {
  for ($y = 0; $y -lt $h; $y += 30) {
    $c = $bmp.GetPixel($x, $y); [void]$colors.Add("$($c.R),$($c.G),$($c.B)")
  }
}
$bmp.Save($Out); $bmp.Dispose()
Write-Output "OK_SCREEN ${w}x${h} colores=$($colors.Count)"
