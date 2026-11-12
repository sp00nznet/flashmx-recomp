# Prove who exported: no original Flash.exe may exist before or during the run.
Get-Process Flash, flashmxrecomp, MMLicenseMgr -EA 0 | Stop-Process -Force
Start-Sleep 3
Remove-Item C:\fl\out -Recurse -Force -EA 0
"before: Flash.exe running = $([bool](Get-Process Flash -EA 0)); out exists = $(Test-Path C:\fl\out)"
$seen = @{}
$job = Start-Job { & C:\fl\harness.ps1 -NoTrial -Exe C:\fl\flashmxrecomp.exe -ArgList "--run --watchdog 500 --game `"C:\Program Files (x86)\Macromedia\Flash MX 2004`" --args C:\fl\make.jsfl" -Keep C:\fl\proof -Timeout 420 }
$t0 = Get-Date
while ($job.State -eq 'Running' -and ((Get-Date) - $t0).TotalSeconds -lt 480) {
    foreach ($p in Get-CimInstance Win32_Process | ? { $_.Name -in 'Flash.exe', 'flashmxrecomp.exe' }) {
        if (-not $seen.ContainsKey($p.ProcessId)) { $seen[$p.ProcessId] = "$($p.Name) pid $($p.ProcessId) parent $($p.ParentProcessId) at +$([int]((Get-Date) - $t0).TotalSeconds)s" }
    }
    if (-not (Test-Path C:\fl\out\done.txt)) { $last = Get-Date }
    Start-Sleep -m 250
}
Receive-Job $job | Select-String 't=|declined'
'processes seen during the run:'; $seen.Values
"done.txt appeared at about +$([int]($last - $t0).TotalSeconds)s"
Get-ChildItem C:\fl\proof | select Name, Length, LastWriteTime | Out-String
"swf sha256: $((Get-FileHash C:\fl\proof\harness.swf -EA 0).Hash)"
