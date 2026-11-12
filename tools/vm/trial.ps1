# The normal trial flow: on the activation dialog (centred on the 1280x800
# desktop) pick "I want to try" and Continue. The dialog's colour at the
# Continue button tells when it is up.
param([int]$Timeout = 90)
Add-Type -AssemblyName System.Drawing
Add-Type 'using System; using System.Runtime.InteropServices; public static class T { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y); [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,IntPtr e); }'
[T]::SetProcessDPIAware() | Out-Null
function Click($x,$y){ [T]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -m 150; [T]::mouse_event(2,0,0,0,[IntPtr]::Zero); Start-Sleep -m 60; [T]::mouse_event(4,0,0,0,[IntPtr]::Zero) }
function Px($x,$y){ $b=New-Object System.Drawing.Bitmap 1,1; [System.Drawing.Graphics]::FromImage($b).CopyFromScreen($x,$y,0,0,$b.Size); $b.GetPixel(0,0) }
# the red Flash logo at (400,230)
$t=0; while($t -lt $Timeout){ $c=Px 894 597; $d=Px 400 230; if($d.R -gt 230 -and $d.G -lt 100){break}; Start-Sleep 1; $t++ }
if ($t -ge $Timeout) { "no activation dialog"; return }
Start-Sleep 4; Click 540 351; Start-Sleep 1; Click 894 597
"trial chosen after $t s"
