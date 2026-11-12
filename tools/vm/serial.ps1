# Enter YOUR OWN Flash MX 2004 serial on Flash's normal serial-entry page
# (the activation dialog's "I have a serial number" -> Continue page), then
# press Continue. Run it inside the throwaway VM only.
#
# The serial comes from the FLASH_SERIAL environment variable, or a prompt if
# it is not set. It is never written to disk, a log, or a screenshot: take no
# screenshot while the entry page is up, since its fields show the serial.
#
#   $env:FLASH_SERIAL = '<your serial>'; & C:\fl\serial.ps1
#
# An UPGRADE serial then asks for the serial of the product it upgrades from
# (the "Enter your previous serial number" page); set FLASH_PREV_SERIAL for
# that, or answer the prompt.
Add-Type -AssemblyName System.Windows.Forms
Add-Type 'using System; using System.Runtime.InteropServices; public static class M { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y); [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,IntPtr e); }'
[M]::SetProcessDPIAware() | Out-Null
function Click($x,$y){ [M]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -m 150; [M]::mouse_event(2,0,0,0,[IntPtr]::Zero); Start-Sleep -m 60; [M]::mouse_event(4,0,0,0,[IntPtr]::Zero) }
function Read-Serial($var, $what) {
    $v = [Environment]::GetEnvironmentVariable($var)
    if (-not $v) { $v = Read-Host "$what (not stored)" }
    $v.Trim()
}

# The four boxes of the entry page, on the dialog centred on 1280x800.
$g = (Read-Serial 'FLASH_SERIAL' 'Your Flash MX 2004 serial').Split('-')
$x = 598, 662, 727, 791
for ($i = 0; $i -lt $g.Count -and $i -lt 4; $i++) { Click $x[$i] 270; Start-Sleep -m 300; [System.Windows.Forms.SendKeys]::SendWait($g[$i]); Start-Sleep -m 300 }
$g = $null
Start-Sleep 1
Click 894 597
"submitted"

# An upgrade serial's next page: one field for the previous product's serial.
if ($env:FLASH_PREV_SERIAL) {
    Start-Sleep 8
    Click 712 262; Start-Sleep -m 300
    [System.Windows.Forms.SendKeys]::SendWait($env:FLASH_PREV_SERIAL.Trim())
    Start-Sleep 1
    Click 894 597
    "previous serial submitted"
}
