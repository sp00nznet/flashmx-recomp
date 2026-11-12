param([string]$Extra = '', [int]$Wait = 40, [string]$Keep = 'C:\fl\rc')
New-Item -ItemType Directory -Force $Keep | Out-Null
$a = "--run --watchdog $Wait $Extra --game `"C:\Program Files (x86)\Macromedia\Flash MX 2004`" --args C:\fl\make.jsfl"
$p = Start-Process C:\fl\flashmxrecomp.exe -ArgumentList $a -PassThru -RedirectStandardError "$Keep\stderr.txt" -RedirectStandardOutput "$Keep\stdout.txt"
$h = $p.Handle
$p.WaitForExit(($Wait + 10) * 1000) | Out-Null
"exit=$($p.ExitCode)"
