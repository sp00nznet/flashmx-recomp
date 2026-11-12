# One-click setup for the Flash MX 2004 static recompilation. Run it by
# double-clicking Setup.cmd in the repo folder; the README's "Step by step" is
# the same thing by hand, command for command.
#
# It checks the tools, copies Flash.exe from your installed Flash MX 2004 into
# work\, finds every function, lifts it to C, builds build\flashmxrecomp.exe
# and leaves a shortcut to it in this folder. Each step is skipped when its
# output already exists (-Force redoes them), so a rerun after a failure
# resumes. Everything goes to setup.log.
#
#   -GameDir <the folder Flash MX 2004 is installed in>   skip the question
#   -Yes                                                  answer yes to every install question
#
# The toolkit is ..\pcrecomp (PCRECOMP overrides it), on its branch
# pcrecomp-flashmx: this project needs that unmerged branch, not main. Under
# recomp-launcher (RECOMP_LAUNCHER=1) it never waits for Enter, and exit code 0 means the
# shortcut is there. Nothing of Flash is ever downloaded.
param([switch]$Force, [switch]$Yes, [Alias('Game')][string]$GameDir = "")
$Game = $GameDir

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Toolkit = $env:PCRECOMP
if (-not $Toolkit) {
  $Toolkit = Join-Path (Split-Path -Parent $Root) 'pcrecomp'
}
$env:PCRECOMP = $Toolkit   # the Python steps read it too
$Log = Join-Path $Root 'setup.log'
Set-Location $Root
function Log($t) { Add-Content -Path $Log -Value $t -Encoding UTF8 }
Log "==== setup $(Get-Date -Format s)"

function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c; Log $t }
function Step($n, $t) { Write-Host ""; Say "[$n/6] $t" 'Cyan' }
function Pause-End { if (-not $Yes -and $env:RECOMP_LAUNCHER -ne '1') { Read-Host "Press Enter to close" | Out-Null } }
function Fail($t) {
  Say ""; Say "Setup stopped: $t" 'Red'
  Say "The details are in $Log. Fix that and run Setup.cmd again; finished steps are skipped." 'Yellow'
  Pause-End; exit 1
}
trap { Fail "$_" }
function Ask($q) { if ($Yes) { Say "$q yes"; return $true }; $a = Read-Host "$q [Y/n]"; return -not ($a -match '^[nN]') }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
# Run a program with its output in the log. Windows PowerShell turns a native
# program's stderr into errors, so 'Stop' is off while it runs.
function Exec([string[]]$cmd) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $rest = @($cmd | Select-Object -Skip 1)   # @(): a one-element slice would splat as characters
  & $cmd[0] @rest 2>&1 | ForEach-Object { Log "$_" }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  return $code
}
function Run($what, [string[]]$cmd) {
  Say "  $what..."
  $code = Exec $cmd
  if ($code -ne 0) { Fail "$what failed (exit code $code)." }
}

if ($env:RECOMP_LAUNCHER -ne '1') { Clear-Host }
Say "Flash MX 2004: static recompilation setup" 'White'
Say "You need your own Flash MX 2004, installed and activated with your own serial (or its trial), and about 6 GB free."
Say "Setup never asks for, stores or uses a serial: you enter yours in Flash's own activation dialog (or with tools\vm\serial.ps1 and FLASH_SERIAL)."

# ---------------------------------------------------------------- tools
Step 1 "Checking the tools"
# A Python that answers "Python 3.x". The Store's placeholder "python" (the
# one that opens the Store) answers nothing, so asking is the reliable test.
function Find-Python {
  # The per-user install winget makes, before PATH has it.
  $user = @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object { ,@($_.FullName) })
  foreach ($c in (@(@('py', '-3'), @('python'), @('python3')) + $user)) {
    if (-not (Get-Command $c[0] -ErrorAction SilentlyContinue)) { continue }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $rest = @($c | Select-Object -Skip 1)
    $v = (& $c[0] @rest --version 2>&1 | Out-String).Trim()
    $ErrorActionPreference = $old
    if ($v -match '^Python 3\.(\d+)' -and [int]$Matches[1] -ge 10) { return ,$c }
  }
  return $null
}
$pyargs = Find-Python
if (-not $pyargs) {
  Say "  Python 3.10 or newer is not installed."
  if (-not (Ask "  Install Python 3.12 now (winget, for your user only, about 30 MB)?")) { Fail "Python 3 is required." }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget is missing. Install 'App Installer' from the Microsoft Store, or install Python yourself."
  }
  Exec @('winget', 'install', '-e', '--id', 'Python.Python.3.12', '--scope', 'user', '--accept-package-agreements', '--accept-source-agreements') | Out-Null
  Refresh-Path
  $pyargs = Find-Python
  if (-not $pyargs) { Fail "Python installed, but it can't be found. Install Python 3.12 from python.org yourself." }
}
Say "  Python: $($pyargs -join ' ')"

if ((Exec ($pyargs + @('-c', 'import pefile, capstone'))) -ne 0) {
  Say "  The Python packages pefile and capstone are missing (about 20 MB)."
  if (-not (Ask "  Install them now (pip, for your user only)?")) { Fail "pefile and capstone are required." }
  Run "Installing pefile and capstone" ($pyargs + @('-m', 'pip', 'install', '--user', 'pefile', 'capstone'))
}

if (-not (Test-Path (Join-Path $Toolkit 'tools\lift\lift32.py'))) {
  Say "  The pcrecomp toolkit is not beside this folder ($Toolkit)."
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not (Ask "  git is needed to fetch it. Install Git for Windows now (winget, about 60 MB)?")) { Fail "git is needed to fetch pcrecomp." }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget is missing. Install Git for Windows yourself." }
    Exec @('winget', 'install', '-e', '--id', 'Git.Git', '--accept-package-agreements', '--accept-source-agreements') | Out-Null
    Refresh-Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "Git did not install. Install Git for Windows yourself." }
  }
  if (-not (Ask "  Download it now (git, about 20 MB)?")) { Fail "pcrecomp is required at $Toolkit." }
  Run "Cloning pcrecomp (branch pcrecomp-flashmx)" @('git', 'clone', '--depth', '1', '-b', 'pcrecomp-flashmx', 'https://github.com/sp00nznet/pcrecomp', $Toolkit)
}
Say "  pcrecomp: $Toolkit"
if (Test-Path (Join-Path $Toolkit '.git')) {
  $br = (& git -C $Toolkit rev-parse --abbrev-ref HEAD 2>$null)
  if ($br -and $br -ne 'pcrecomp-flashmx') { Say "  Note: pcrecomp is on '$br'; this project is built and tested on 'pcrecomp-flashmx'." 'Yellow' }
}

# Visual Studio 2022 or its Build Tools, with the C++ x86 compiler; CMake and
# Ninja ship inside that workload, so build.cmd needs nothing else.
function Find-VS {
  foreach ($p in @("${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
                   "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe")) {
    if (Test-Path $p) {
      $vs = & $p -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
      if ($vs) { return $vs }
    }
  }
  foreach ($d in (Get-ChildItem "$env:ProgramFiles\Microsoft Visual Studio\2022", "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022" -Directory -ErrorAction SilentlyContinue)) {
    if (Test-Path "$($d.FullName)\VC\Auxiliary\Build\vcvarsall.bat") { return $d.FullName }
  }
  return $null
}
if (-not (Find-VS)) {
  Say "  Visual Studio 2022 with the C++ tools is not installed. The recompiled program is C, and this is the compiler."
  if (-not (Ask "  Install the Visual Studio 2022 Build Tools with the C++ workload now (winget, about 3 GB)?")) { Fail "a C compiler (Visual Studio 2022 C++) is required." }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget is missing. Install Visual Studio 2022 Build Tools with 'Desktop development with C++' yourself." }
  Exec @('winget', 'install', '-e', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--accept-package-agreements', '--accept-source-agreements',
         '--override', '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended') | Out-Null
  if (-not (Find-VS)) { Fail "the Build Tools did not install. Install Visual Studio 2022 with 'Desktop development with C++' yourself." }
}
Say "  C compiler: $(Find-VS)"

# ---------------------------------------------------------------- the program
# Flash licenses itself through Macromedia's licensing service, which only its
# own installer sets up, so the recomp runs against an installed copy and
# nothing is unpacked: Flash.exe is copied into work\ to be read.
Step 2 "Finding your installed Flash MX 2004"
if ((Test-Path 'work\Flash.exe') -and (Test-Path 'work\gamedir.txt') -and -not $Force) {
  $Game = (Get-Content 'work\gamedir.txt').Trim()
  Say "  $Game (skipping)."
} else {
  $Game = $Game.Trim('"', ' ')
  $default = "${env:ProgramFiles(x86)}\Macromedia\Flash MX 2004"
  if (-not $Game -and (Test-Path "$default\Flash.exe")) { $Game = $default }
  if (-not $Game -and $Yes) { Fail "give the folder Flash MX 2004 is installed in with -GameDir." }
  while (-not $Game) {
    $Game = (Read-Host "  Where is Flash MX 2004 installed (the folder holding Flash.exe)?").Trim('"', ' ')
  }
  if (-not (Test-Path (Join-Path $Game 'Flash.exe'))) { Fail "$Game holds no Flash.exe. Install Flash MX 2004 first (README, Getting started)." }
  $Game = (Resolve-Path $Game).Path
  New-Item -ItemType Directory -Force 'work' | Out-Null
  Copy-Item (Join-Path $Game 'Flash.exe') 'work\Flash.exe' -Force
  $Game | Set-Content 'work\gamedir.txt'
  Say "  $Game"
}

# ---------------------------------------------------------------- catalog
Step 3 "Finding every function (about 25 minutes)"
if ((Test-Path 'work\functions.json') -and -not $Force) { Say "  Already done (skipping)." }
else { Run "Disassembling Flash.exe" ($pyargs + @((Join-Path $Toolkit 'tools\disasm\disasm32.py'), 'work\Flash.exe', '-o', 'work\functions.json')) }

# ---------------------------------------------------------------- lift
Step 4 "Recompiling Flash.exe to C (about 10 minutes)"
if ((Test-Path 'src\recomp\gen\recomp_dispatch.c') -and -not $Force) { Say "  Already done (skipping)." }
else {
  Run "Listing exception funclets" ($pyargs + @('tools\eh_seeds.py'))
  Run "Lifting" ($pyargs + @('run_lift.py'))
}

# ---------------------------------------------------------------- build
Step 5 "Building build\flashmxrecomp.exe (30 to 60 minutes)"
if ((Test-Path 'build\flashmxrecomp.exe') -and -not $Force) { Say "  Already built (skipping)." }
else {
  $env:CMAKE_ARGS = "-DPCRECOMP=$($Toolkit -replace '\\', '/')"
  Run "Compiling" @('cmd', '/d', '/c', "`"$Root\build.cmd`"")
}

# ---------------------------------------------------------------- shortcut
Step 6 "Making the shortcut"
$lnk = Join-Path $Root 'Flash MX 2004.lnk'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = Join-Path $Root 'build\flashmxrecomp.exe'
$s.Arguments = "--run --game `"$Game`""
$s.WorkingDirectory = $Root
$s.IconLocation = (Join-Path $Game 'Flash.exe') + ',0'
$s.Save()
Say "  $lnk"

if (-not (Test-Path $lnk)) { Fail "the shortcut was not made." }
Write-Host ""
Say "Done. Double-click 'Flash MX 2004' in this folder to run it." 'Green'
Pause-End
exit 0
