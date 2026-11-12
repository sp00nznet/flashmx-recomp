# Macromedia Flash MX 2004, recompiled

Static recompilation of **Macromedia Flash MX 2004** (Macromedia, 2004), the
Flash authoring tool (Flash 7), from its shipping Win32 executable to native
C. No emulator, no wrapper DLLs.

It is pcrecomp's first **Visual C++ 7.1 / MFC 7.1** program, its first with
Microsoft SEH used as deliberate control flow by an anti-debug licensing
client, and its first that drives the real, vendor licensing service during
bring-up.

Built on the [pcrecomp](https://github.com/sp00nznet/pcrecomp) toolchain and
following its shared house style (layout, CLI, conformance harness), like the
other [pcrecomp projects](https://github.com/sp00nznet/pcrecomp#the-projects-that-built-this).

## What it is

A static recompilation of `Flash.exe` (Flash MX 2004 7.2, PE stamp
`0x40EE908A`, 2004-07-09; MFC 7.1 statically linked in, ~10 MB of code).
pcrecomp lifts `Flash.exe` to C, MSVC compiles the C, and pcrecomp's
`native32` host runs it. The DLLs it loads — `xerces-c_2_1_0`, `GdiPlus`,
MSLU (`unicows`), the Macromedia SafeCast/FLEXnet licensing client — run
natively and are called through the host's bridge.

**Licensing is never faked.** Bring-up installs the real Flash MX 2004 (its
30-day trial), the installer sets up the real **Macromedia Licensing
Service**, and the recomp is run against that same service through the normal
trial flow. The license file, the trial check and the service are the
original's. See *Status* for how far that gets.

## Status: pre-alpha. It runs Flash's real start-up and reaches the licensing client; it does not yet open the authoring window.

| Stage | State |
|---|---|
| Version recompiled | Flash MX 2004 7.2 (`Flash.exe`, 2004-07-09), run in its 30-day trial |
| Installer | **run by you**, in a throwaway VM (the licensing service it sets up is needed; nothing is unpacked). The recomp reads the installed `Flash.exe` only |
| Function catalog (`disasm32`) | 34,229 functions, 86.5% of the code range |
| Lift (`run_lift.py`) | 120,886 functions, 0 errors; +37k C++/SEH exception funclets seeded (`tools/eh_seeds.py`), 966 functions given SEH/C++ landing pads |
| Host (`build/flashmxrecomp.exe`, 32-bit, `native32`) | 698 imports bound, 0 unresolved; MFC, xerces, GdiPlus and the licensing client run natively |
| Start-up | MFC/CRT init, MSLU (unicows) thunks, the registry edition/registration reads, and the first window-procedure callbacks all run |
| Licensing client | reached. `Flash.exe` loads the SafeCast/FLEXnet client, which runs **obfuscated, code-virtualized anti-debug** that raises software interrupts (`int 1`, `int n`) inside `__try` as covert control flow |
| Authoring window, `.swf` export (`tools/vm/make.jsfl`) | **not reached** — blocked at the anti-debug client (see [docs/bringup.md](docs/bringup.md)) |
| Conformance harness (`tools/swf_diff.py`) | makes reference `.fla`/`.swf` with the original and would diff the recomp's output; **SKIP** until the recomp exports |

Built and tested against pcrecomp branch `pcrecomp-flashmx` (on
`pcrecomp-retailplus`), which adds the x86 software-interrupt → guest-SEH
trap, the C++-throw-across-callback boundary, and the exception-funclet
seeding this program needed.

### Why it stops where it stops

The licensing client is not ordinary code. It is obfuscated and
code-virtualized (xor-keyed dispatchers, a software-interrupt VM) and uses
Microsoft SEH as its interpreter loop: it executes `int 1` / `int n` inside
`__try`, which faults on NT, and takes the `__except` block — a debugger would
swallow the interrupt, so the fault *is* the check. The recomp now reproduces
that faithfully: the interrupt faults (pcrecomp `RECOMP_TRAP`), the fault is
offered to the guest's own SEH chain (`native32_guest_seh`), the guest handler
runs and `RtlUnwind`s. But the obfuscated `__except` continuation then
computes on exact fault-`CONTEXT` state (registers and `Eip` at the faulting
instruction) that the host's minimal `CONTEXT` does not reproduce, and the VM
takes its tamper path and ends the process.

Finishing this means reproducing a virtualized protector's exception-driven
interpreter exactly — a large, separate toolkit effort, not a licensing
shortcut. Per the project rules, faking the service, the license file or the
trial check is not allowed, so the honest result is: **the recomp runs Flash's
real code up to the real anti-debug client and stops there.** Someone with a
retail serial (which skips the trial anti-debug path) can carry it further.

## Screenshots

None yet: the authoring window is not reached. `tools/vm/make.jsfl` builds a
small document and exports `harness.swf` with the **original** Flash.exe (used
as the oracle); the recomp does not yet get that far.

## What is not in this repo

Nothing of Flash: no executable, DLL, license file, or generated source. The
recompiled C is produced on your machine from your own installed copy by
`run_lift.py`, into `src/recomp/gen/`, which is gitignored.

## Getting Started

You need **your own Macromedia Flash MX 2004**. Because the licensing service
must be installed, and because its anti-debug code runs during start-up, do
all of this **in a throwaway Windows VM**, never on your workstation:

1. Install Flash MX 2004 from your own disc (its 30-day trial is fine). This
   sets up the Macromedia Licensing Service.
2. Double-click `Setup.cmd` (or run `tools\setup.ps1`). It copies the
   installed `Flash.exe` into `work\`, catalogs it, lifts it, and builds
   `build\flashmxrecomp.exe`. About an hour and 6 GB.
3. Run `build\flashmxrecomp.exe --run --game "C:\Program Files (x86)\Macromedia\Flash MX 2004"`.

`docs/bringup.md` has the step-by-step, the netlab VM recipe, and the
licensing analysis.

## License

MIT (the recomp host, the lift driver and the tools). Flash MX 2004 is
© 2004 Macromedia, Inc.; no part of it is in this repo.
