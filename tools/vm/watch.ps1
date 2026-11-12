param([string]$Extra = "")
$j = Start-Job { param($x) & C:\fl\rc.ps1 -Wait 200 -Extra $x } -ArgumentList $Extra
Start-Sleep 12
$c = Get-CimInstance Win32_Process | ? { $_.Name -eq 'flashmxrecomp.exe' } | ? { (Get-Process -Id $_.ParentProcessId -EA 0).Name -eq 'flashmxrecomp' }
$cp = Get-Process -Id $c.ProcessId
$h = $cp.Handle
($cp.Modules | % { $_.ModuleName }) -join ' '
'--'
& C:\fl\trial.ps1 -Timeout 60
$t0 = Get-Date
while (-not $cp.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt 60) { Start-Sleep -m 200 }
"child exited after $(((Get-Date) - $t0).TotalSeconds) s code $($cp.ExitCode)"
Get-CimInstance Win32_Process | ? { $_.Name -match 'MMLicense|Licens|flash' } | select ProcessId,ParentProcessId,Name | ft -auto | Out-String
Wait-Job $j -Timeout 60 | Out-Null
Get-Process flashmxrecomp,MMLicenseMgr -EA 0 | Stop-Process -Force
