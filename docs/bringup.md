# Bring-up

How Flash MX 2004 was recompiled and run, how its licensing client was
passed without faking anything, and how the output was verified. All of it
was done in **throwaway Windows VMs** on the netlab Proxmox lab, never on a
workstation, because the installer sets up a licensing service and the
licensing client runs anti-debug code.

## The binary
- `Flash.exe`: VC++ 7.1, MFC 7.1 statically linked in, base `0x00400000`, PE
  stamp `0x40EE908A` (2004-07-09), 13,213,696 bytes, SHA-256
  `86962d87…650841836`. Not packed, no relocations, no TLS. `.text` is
  `0x401000`–`0xDF4000` (~10 MB).
- Licensing strings: `CSafeCastValidator`, `MMxptLite_Mach5::IsLicenseGood /
  IsTrialLicense / GetLicensePeriod`, `FLEXnet Activation Library (Selfoss)`,
  `\MLM\MMLicenseMgr.exe`, `Macromedia Licensing Service`.

## Catalog and lift
- `disasm32.py work/Flash.exe -o work/functions.json`: 34,229 functions,
  86.5% byte coverage (no `--tail-jumps`; this is MFC, not VO stub chains).
- `tools/eh_seeds.py` → `work/seeds.json`. MSVC's catch and unwind funclets
  are reached only through the FuncInfo tables, never by a call, so the
  catalog misses ~37k of them. eh32 then reports "funclet 0x… is not lifted"
  and the throw dies. The script reads every `mov eax, FuncInfo; jmp
  __CxxFrameHandler` stub and lists its funclets.
- `run_lift.py`: 119,767 functions, 0 errors. The 966 functions that install
  an MSVC exception frame get a landing pad (`RECOMP_EH_FRAME`, from
  `eh32.frame`). Their 1,146 `__except`/catch continuations are kept **out of
  the dispatch table** (see "The licensing client").

## The host (`src/runtime/host.c`)
- Bully's pattern: `native32_hold_image` keeps `0x00400000` plus 14 MB free,
  and the host runs on a 16 MB thread. The guest image overlaps where Windows
  puts the first thread's stack.
- **MSLU (unicows).** Flash links `unicows.lib`. Its W-function pointers
  start at a resolver thunk (`push fail; push [hmod]; push &slot; push "Name";
  push "kernel32.dll"; call resolve`) that walks kernel32's exports itself, so
  neither the import binding nor `native32_redirect`'s GetProcAddress hook
  sees it. `mslu_redirect` finds the thunk and fills the slot before the guest
  runs. Without it, `CWinApp::SetCurrentHandles` threw `CUserException` because
  `GetModuleFileNameW(0x00400000)` failed.
- `native32_guest_seh = 1`: guest exceptions go to the guest's own handlers.
- Tracing behind environment variables: `FL_TRACE_REG` (registry calls),
  `FL_TRACE_EXIT` (hooks `NtTerminateProcess` and reports whatever ends the
  process), `NATIVE32_TRACE_EH` (C++ throws, the SEH chain).

## What runs before licensing
MFC/CRT init; MSLU; `CRegistry` probes under `Software\Macromedia\Flash 7`,
`…\Flash\7.0\Registration` and `…\Installation\Edition`. These throw
`REGISTRY_ERROR` and `int` exceptions internally, all caught by guest frames;
the funclet seeding made that work. Then come the first window-procedure
callbacks. One of them (sub_00CEC0A1, the splash's WM_SIZE path) lets an `int`
throw escape the window procedure when `SplashScreenType` is missing.
Windows drops such an exception at the callback boundary. pcrecomp now does
the same (eh32 + `cb_run`), and the callback returns 0.

## The licensing client, and how it got through
Call chain into it: `… → sub_00C62EF0 → sub_00C69D60`. sub_00C69D60 installs
an MSVC `__try` (handler `_except_handler3` at `0x00A7F994`, scope table
`0x00EBC0C8`: filter `0x00C69D94`, `__except` block `0x00C69DA5`). Then it
executes **`int 1`** (`0x00C69D90`). Nearby code also executes `int 0x68`.
On NT a software interrupt faults. Under a debugger the debugger eats it.
So reaching the `__except` block is the "no debugger" answer, and missing it
sends the client to its tamper path (sub_00C62EF0 wipes the stack and
terminates). The licensed install runs this exactly like the trial does; a
serial does not skip it.

What it took, in the order the runs showed it:
1. **`int n` must fault** (pcrecomp `RECOMP_TRAP`). Lifted as a no-op it gave
   the debugger answer, and the process died with a garbage exit code.
2. **The guest's own SEH must handle it** (`native32_guest_seh`). The chain
   is walked, `_except_handler3` runs the filter, and `RtlUnwind` completes.
3. **The `__except` block must not be a function.** disasm32 had catalogued
   `0x00C69DA5`, a scope-table pointer, as a function entry. Its dispatch
   entry caught the handler's jump and ran the block as a function of its
   own, with no landing pad and the wrong frame, and `_except_handler3`
   faulted. With continuations kept out of dispatch, the jump misses,
   `recomp_eh_jump` finds the parent body's `RECOMP_EH_FRAME`, and execution
   continues inside sub_00C69D60, as native code does:
   `[eh32] continue at 0x00C69DA5 in sub_00C69D60`.

An earlier diagnosis, an incomplete fault `CONTEXT`, was wrong. The fault
inside `_except_handler3` came from the dispatched `__except` block.

## The result
On the licensed install, with no original Flash.exe running (checked by
`tools/vm/proof.ps1`, which records every Flash process during the run):
- the recomp passes licensing and opens the authoring window
  (`docs/screenshots/authoring.png`);
- it runs `make.jsfl`: saves `harness.fla`, exports `harness.swf`, and quits
  with `ExitProcess(0)`;
- **the `.swf` is byte-identical to the original's**, SHA-256
  `7C908BA3441784C04C7B4491C011DE9D31814CA2899FAEBF0B47F1AEEBE81302`. The
  original makes the same file in trial and licensed mode, on every run.
  The `.fla` carries a save timestamp and differs between any two runs,
  the original's included.

## The retail path (your own serial)
`tools/vm/serial.ps1` types **your own** serial into Flash's normal
serial-entry page and presses Continue. The serial comes from `FLASH_SERIAL`
or a prompt. Run it only in the throwaway VM. It never stores the serial, and
no screenshot may be taken while the entry page is up.

Tried on 2026-11-12 with two user-supplied serials, each in a fresh
throwaway clone that was destroyed afterwards:
- a Flash **upgrade** serial. Flash then asked for the previous product's
  serial ("Enter your previous serial number"). None was available, so that
  run stopped there.
- a **Studio MX 2004** serial. Flash's own flow showed "Activation is
  complete" (registration is optional; "Remind Me Later"). The result above
  was produced on that licensed install.

Nothing was guessed or faked.

## The oracle and the harness
`tools/vm/make.jsfl` builds a 320×240 document (a rectangle, an oval, a line,
text, a second keyframe and a frame-1 `trace`), saves `harness.fla`, and
exports `harness.swf`. `tools/vm/harness.ps1` runs it with either exe. It
declines the IE "install Flash Player" prompt, found by a wildcard title
search; `-NoTrial` skips the trial clicks for a licensed install.
`tools/vm/proof.ps1` runs the recomp with no original Flash.exe present and
reports the `.swf` hash. `tools/swf_diff.py` compares two `.swf` files.

## Netlab VM recipe
Uncommitted, in `F:/projects/tools/recomp-netlab/local/projects/flashmx.env`
(per the project rules). Make a throwaway full clone of the Windows test box
(VM 103) with a ZFS `send | recv` of each disk; a live TPM disk can't be
`qm clone`d. Install Flash and run the recomp inside it, then destroy it. The
throwaways used here (VM 135, three times) were all destroyed, and testbox
itself was never modified.
