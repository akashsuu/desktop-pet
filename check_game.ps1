Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$hwnd = [Win32]::GetForegroundWindow()
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Output "0"
    exit
}

$className = New-Object System.Text.StringBuilder 256
[Win32]::GetClassName($hwnd, $className, 256) | Out-Null
if ($className.ToString() -eq "WorkerW" -or $className.ToString() -eq "Progman") {
    # Desktop
    Write-Output "0"
    exit
}

$rect = New-Object Win32+RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

if ($width -ge $screen.Width -and $height -ge $screen.Height) {
    Write-Output "1"
} else {
    Write-Output "0"
}
