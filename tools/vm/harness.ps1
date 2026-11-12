# Run Flash (original or recomp) on make.jsfl through the normal trial flow,
# decline the IE "install Flash Player" prompt, wait for the export, keep outputs.
param([string]$Exe, [string]$ArgList, [string]$Keep, [int]$Timeout = 300)
$ErrorActionPreference = 'Continue'
Add-Type 'using System; using System.Runtime.InteropServices; public static class H { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c,string t); [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); public struct RECT { public int L,T,R,B; } [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y); [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,IntPtr e); }'
[H]::SetProcessDPIAware() | Out-Null
New-Item -ItemType Directory -Force C:\fl\out, $Keep | Out-Null
Remove-Item C:\fl\out\* -EA 0
$p = Start-Process $Exe -ArgumentList $ArgList -PassThru -RedirectStandardError "$Keep\stderr.txt" -RedirectStandardOutput "$Keep\stdout.txt"
& C:\fl\trial.ps1 -Timeout 120
$t = 0
while (-not (Test-Path C:\fl\out\done.txt) -and $t -lt $Timeout -and -not $p.HasExited) {
    $h = [H]::FindWindow($null, 'Flash MX 2004 - Security Warning')
    if ($h -ne [IntPtr]::Zero) {
        $r = New-Object H+RECT; [H]::GetWindowRect($h, [ref]$r) | Out-Null
        [H]::SetForegroundWindow($h) | Out-Null; Start-Sleep -m 300
        [H]::SetCursorPos($r.L + 398, $r.T + 122) | Out-Null; Start-Sleep -m 150
        [H]::mouse_event(2,0,0,0,[IntPtr]::Zero); [H]::mouse_event(4,0,0,0,[IntPtr]::Zero)
        "declined the player install at $t s"
    }
    Start-Sleep 1; $t++
}
Start-Sleep 5
& C:\fl\shot.ps1 "$Keep\end.png"
"t=$t exited=$($p.HasExited) code=$(if($p.HasExited){$p.ExitCode})"
Stop-Process -Id $p.Id -Force -EA 0
Copy-Item C:\fl\out\* $Keep
Get-ChildItem $Keep | select Name,Length | Out-String
