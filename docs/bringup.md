# Bring-up

How Flash MX 2004 was recompiled and run, what the licensing client does, and
where it blocks. Everything here was done in a **throwaway Windows VM** on the
netlab Proxmox lab, never on a workstation, because the installer sets up a
licensing service and the licensing client runs anti-debug code.

## The binary
- `Flash.exe`: VC++ 7.1, MFC 7.1 statically linked in, base `0x00400000`, PE
  stamp `0x40EE908A` (2004-07-09), 13,213,696 bytes, SHA-256
  `86962d87…650841836`. Not packed, no relocations, no TLS. `.text` is
  `0x401000`–`0xDF4000` (~10 MB). Imports: KERNEL32, MFC71, xerces, GdiPlus,
  ole32/oleaut32, wininet, ws2_32, unicows (MSLU) and the rest.
- Licensing strings: `CSafeCastValidator`, `MMxptLite_Mach5::IsLicenseGood /
  IsTrialLicense / GetLicensePeriod`, `FLEXnet Activation Library (Selfoss)`,
  `Macrovision\SafeCast\Product Licenses\…`, `\MLM\MMLicenseMgr.exe`,
  `Macromedia Licensing Service`.

## Catalog and lift
- `disasm32.py work/Flash.exe -o work/functions.json` (no `--tail-jumps`;
  this is MFC, not the VO stub chains that flag needed): 34,229 functions,
  86.5% byte coverage.
- `tools/eh_seeds.py` → `work/seeds.json`: MSVC's C++ catch funclets and
  unwind (destructor) funclets are reached only through the FuncInfo tables,
  never by a call, so the catalog misses ~37k of them; eh32 then reports
  "funclet 0x… is not lifted" and the throw dies. The script reads every
  `mov eax, FuncInfo; jmp __CxxFrameHandler` stub and lists its funclets.
- `run_lift.py`: 120,886 functions, 0 errors. It also gives the 966 functions
  that install an MSVC exception frame a landing pad (`RECOMP_EH_FRAME`, via
  `eh32.frame`), so a guest handler can jump back into a lifted body.

## The host (`src/runtime/host.c`)
- Bully's pattern: `native32_hold_image` keeps `0x00400000`+14 MB free and the
  host runs on a 16 MB thread (the first thread's stack is tiny), because the
  guest image overlaps where Windows puts the first stack.
- **MSLU (unicows).** Flash links `unicows.lib`, whose W-function pointers
  start at a resolver thunk (`push fail; push [hmod]; push &slot; push "Name";
  push "kernel32.dll"; call resolve`) that walks kernel32's exports itself —
  neither the import binding nor `native32_redirect`'s GetProcAddress hook sees
  it. `mslu_redirect` scans `.text` for the thunk and fills the slot before the
  guest runs, so the host answers `GetModuleFileNameW`/`GetModuleHandleW`/
  `GetCommandLineW`. Without this, `CWinApp::SetCurrentHandles` threw
  `CUserException` because `GetModuleFileNameW(0x00400000)` failed.
- Tracing behind env vars: `FL_TRACE_REG` logs the A/W registry calls,
  `FL_TRACE_EXIT` hooks `NtTerminateProcess` to catch whatever ends the
  process by any route, `NATIVE32_TRACE_EH` logs the C++ throws and the SEH
  chain.

## What runs
With those in place the recomp runs, in order: MFC/CRT init; MSLU set-up;
a flurry of `CRegistry` probes under `HKCU/HKLM\Software\Macromedia\Flash 7`,
`…\Flash\7.0\Registration`, `…\Installation\Edition` (these throw
`REGISTRY_ERROR` and `int` exceptions internally — all caught by guest
frames, which the eh32 funclet seeding made possible); the first
window-procedure callbacks (sub_00CEC0A1, a WM_ dispatcher). Then it enters
the licensing client.

## The licensing client (the blocker)
Call chain into it: `… → sub_00C62EF0 → sub_00C69D60`. sub_00C69D60 installs
an MSVC `__try` (handler `_except_handler3` at `0x00A7F994`) and immediately
executes **`int 1`** (`0x00C69D90`). Nearby code executes `int 0x68` and more.
The dispatchers around it (sub_00C62380, sub_00C61BF0, sub_00C31860, …) are
xor-keyed obfuscation with no normal structure — a software-interrupt VM.

This is a standard virtualized-protector trick: a software interrupt faults on
NT; under a debugger the debugger eats it; so the code runs the interrupt
*inside* `__try` and uses reaching the `__except` block as proof no debugger is
attached. The fault is the check.

### What the recomp now does (honestly, no fake)
1. `int 1` / `int n` no longer lift to a no-op (which looked like a debugger).
   The lifter emits `RECOMP_TRAP(0xC0000005, va)` (pcrecomp
   `pcrecomp-flashmx`), which faults as NT would.
2. The host turns on `native32_guest_seh`, so the trap is offered to the
   guest's own SEH chain (`seh_trap` → `seh_dispatch`). The chain is walked,
   the guest handler (`_except_handler3`) runs, and `RtlUnwind` completes to
   the innermost frame.
3. But the obfuscated `__except` continuation then faults inside
   `_except_handler3` (reading an obfuscated pointer computed from the
   exception `CONTEXT`). The host's `CONTEXT` carries the integer + control
   registers and `Eip = t_trap_va`, which is not enough for the VM's pointer
   math, so it takes its tamper path and calls `NtTerminateProcess`.

So the recomp reaches and runs the real anti-debug client against the real
Macromedia Licensing Service, and stops there. Finishing it means reproducing
the protector's exception-driven interpreter exactly (see ROADMAP), or using a
retail serial, which does not take the trial anti-debug path.

## The retail path
A retail serial skips the trial anti-debug path. `tools/vm/serial.ps1` types
**your own** serial, from `FLASH_SERIAL` or a prompt, into Flash's normal
serial-entry page and presses Continue. Run it only in the throwaway VM. It
never stores the serial, and no screenshot is taken while the entry page is up.

Tried on 2026-11-12 in a fresh throwaway clone (destroyed afterwards) with a
user-supplied serial. The entry page accepted it as an **upgrade** serial and
moved to "Enter your previous serial number. This upgrade requires you to
enter the serial number of the product from which you are upgrading." No
previous serial was available, so the retail path stopped there, before any
activation step. Nothing was guessed or faked. Next time: a full serial, or
the upgrade serial plus the previous product's (`FLASH_PREV_SERIAL`). After
that, Flash may need online activation, and Macromedia's activation servers
no longer exist. If it won't activate, stop there too.

## The oracle and the harness
`tools/vm/make.jsfl` builds a 320×240 document (rectangle, oval, line, text, a
second keyframe, a frame-1 `trace`) and exports `harness.swf`, run by the
**original** Flash.exe through the normal trial flow (the activation dialog's
"I want to try" → Continue; decline the IE Flash-Player prompt). On the test
VM it makes a deterministic `harness.swf` (SHA-256 `7C908BA3…`; the `.fla`
embeds a timestamp and is not deterministic). `tools/swf_diff.py` would run the
same `.jsfl` on the recomp and diff the `.swf` byte-for-byte; it SKIPs until
the recomp exports.

## Netlab VM recipe
Uncommitted, in `F:/projects/tools/recomp-netlab` (per the project rules):
clone the Windows test box (VM 103) to a throwaway full clone via a ZFS
`send | recv` of each disk (a live TPM disk cannot be `qm clone`d), run the
installer and the recomp inside it, roll back or destroy afterwards. The
throwaway used here was VM 135 on dpiprox2; destroy it when done.
