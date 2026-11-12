param([string]$Out = 'C:\fl\shot.png')
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type 'using System.Runtime.InteropServices; public static class D { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }'
[D]::SetProcessDPIAware() | Out-Null
$r = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$b = New-Object System.Drawing.Bitmap $r.Width, $r.Height
[System.Drawing.Graphics]::FromImage($b).CopyFromScreen($r.X, $r.Y, 0, 0, $b.Size)
$b.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
