param([double]$RelX = 0.5, [double]$RelY = 0.5)
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ClickW {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[ClickW]::SetProcessDPIAware() | Out-Null
$proc = Get-Process PortalPilotWorkspace -ErrorAction Stop
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "NO_WINDOW"; exit 1 }
[ClickW]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400
$rect = New-Object ClickW+RECT
[ClickW]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$x = [int]($rect.Left + ($rect.Right - $rect.Left) * $RelX)
$y = [int]($rect.Top + ($rect.Bottom - $rect.Top) * $RelY)
[ClickW]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 250
[ClickW]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
[ClickW]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
Write-Output "CLICK ${x},${y}"
