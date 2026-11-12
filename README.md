# Macromedia Flash MX 2004, recompiled

Static recompilation of **Macromedia Flash MX 2004** (Macromedia, 2004), the
Flash authoring tool (Flash 7), from its shipping Win32 executable to native
C. No emulator, no wrapper DLLs.

It is pcrecomp's first **Visual C++ 7.1 / MFC 7.1** program, and its first
whose licensing client runs anti-debug code that uses Microsoft SEH as control
flow (software interrupts inside `__try`).

Built on the [pcrecomp](https://github.com/sp00nznet/pcrecomp) toolchain and
following its shared house style (layout, CLI, conformance harness), like the
other [pcrecomp projects](https://github.com/sp00nznet/pcrecomp#the-projects-that-built-this).

## What it is

A static recompilation of `Flash.exe` (Flash MX 2004 7.2, PE stamp
`0x40EE908A`, 2004-07-09; MFC 7.1 statically linked in, ~10 MB of code).
pcrecomp lifts `Flash.exe` to C, MSVC compiles the C, and pcrecomp's
`native32` host runs it. The DLLs it loads — `xerces-c_2_1_0`, `GdiPlus`,
MSLU (`unicows`), the Macromedia licensing client — run natively and are
called through the host's bridge.

**Licensing is never faked.** It runs against a real, licensed install: the
real Macromedia Licensing Service, activated through Flash's own serial-entry
flow with the user's own serial. The recomp passes Flash's own licensing and
anti-debug checks by running them faithfully, not by skipping them.

## Status: v0.2.0, alpha. The authoring window opens, and a published .swf matches the original byte for byte

| Stage | State |
|---|---|
| Version recompiled | Flash MX 2004 7.2 (`Flash.exe`, 2004-07-09), licensed with the user's own serial (a Studio MX 2004 serial) |
| Installer | **run by you**, in a throwaway VM (it sets up the licensing service). The recomp reads the installed `Flash.exe`; nothing is unpacked |
| Function catalog (`disasm32`) | 34,229 functions, 86.5% of the code range |
| Lift (`run_lift.py`) | 119,767 functions, 0 errors; ~37k C++/SEH exception funclets seeded (`tools/eh_seeds.py`); 966 functions with SEH/C++ landing pads; 1,146 `__except`/catch continuations kept out of dispatch |
| Host (`build/flashmxrecomp.exe`, 32-bit, `native32`) | 698 imports bound, 0 unresolved |
| Licensing + anti-debug | **passes**, through the real service and Flash's own checks (the `int 1` / `int n` traps inside `__try` fault and are handled as on NT) |
| Authoring window | **opens**: tools, timeline, Start Page, Properties, panels ([screenshot](docs/screenshots/authoring.png)) |
| JSFL automation | `tools/vm/make.jsfl` runs in the recomp: it builds a document, saves `harness.fla`, exports `harness.swf`, and quits |
| Conformance (`.swf` vs the original's) | **IDENTICAL**: SHA-256 `7C908BA3…EBE81302` from both (`tools/vm/proof.ps1`; no original Flash.exe ran during the recomp's run). The `.fla` embeds a save timestamp and differs between any two runs, the original's included |

Built and tested against pcrecomp branch `pcrecomp-flashmx` (on
`pcrecomp-retailplus`).

### How licensing got through (no fakes)
The licensing client raises software interrupts (`int 1`, `int n`) inside
`__try` and takes the `__except` block as "no debugger attached". Three things
had to be right:
1. **The interrupt has to fault.** Lifted as a no-op it looked like a
   debugger. pcrecomp now lifts it to `RECOMP_TRAP`, which faults as NT does
   and hands the fault to the guest's own SEH chain.
2. **The guest's own handler runs.** The host turns on `native32_guest_seh`.
   `_except_handler3` runs the filter and `RtlUnwind`s.
3. **The `__except` block has to be a label, not a function.** disasm32 takes
   a scope table's `__except` pointers for functions. Left in the dispatch
   table, the handler's jump into the block ran it as a separate function,
   with the wrong frame, and the check failed. `run_lift.py` now keeps those
   continuations out of dispatch, so the jump lands in the parent body's
   landing pad (as SWGB's driver does).

A retail serial does **not** skip the check. The licensed install hits the
same `int 1` path as the trial.

### Your own serial
Flash needs a licensed install (or its 30-day trial). Use **your own** serial
only, inside the throwaway VM, at run time: set `FLASH_SERIAL` (or answer the
prompt) and run `tools\vm\serial.ps1` on Flash's normal serial-entry page. The
serial is never stored, logged, committed or screenshotted. If your serial is
an upgrade serial, Flash also asks for the previous product's serial
(`FLASH_PREV_SERIAL`). A Studio MX 2004 serial registers Flash MX 2004 as
part of Studio and activated directly in testing.

## Screenshots

The authoring window, running as recompiled code (the licensed install; no
original Flash.exe running):

![The Flash MX 2004 authoring window, recompiled](docs/screenshots/authoring.png)

## What is not in this repo

Nothing of Flash: no executable, DLL, license file, serial, or generated
source. The recompiled C is produced on your machine from your own installed
copy by `run_lift.py`, into `src/recomp/gen/`, which is gitignored.

## Getting Started

You need **your own Macromedia Flash MX 2004**, installed and licensed (your
serial, or its 30-day trial). Because the installer sets up a licensing
service, do this **in a throwaway Windows VM**:

1. Install Flash MX 2004 from your own disc. Activate it with your own serial
   (Flash's activation dialog → "I have a serial number"), or use the trial.
2. Double-click `Setup.cmd` (or run `tools\setup.ps1`). It copies the
   installed `Flash.exe` into `work\`, catalogs it, lifts it, and builds
   `build\flashmxrecomp.exe`. About an hour and 6 GB.
3. Run `build\flashmxrecomp.exe --run --game "C:\Program Files (x86)\Macromedia\Flash MX 2004"`.
   Pass a JSFL script with `--args script.jsfl`.

The conformance check is `tools\vm\proof.ps1` (in the VM, after
`tools\vm\harness.ps1` has made the original's reference `.swf`). See
[docs/bringup.md](docs/bringup.md).

## License

MIT (the recomp host, the lift driver and the tools). Flash MX 2004 is
© 2004 Macromedia, Inc.; no part of it is in this repo.
