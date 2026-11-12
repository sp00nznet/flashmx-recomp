# Changelog

## [0.2.0] - 2026-11-12

The authoring window opens, and a published `.swf` matches the original's
byte for byte.

### Fixed
- `run_lift.py` keeps `__except`/catch continuations (1,146) out of the
  dispatch table. disasm32 takes a scope table's `__except` pointers for
  functions, so `_except_handler3`'s jump into an `__except` block ran it as a
  separate function. That broke the licensing client's anti-debug check (an
  `int 1` inside `__try`). Now the jump lands in the parent body's
  `RECOMP_EH_FRAME` landing pad, and the check passes as it does natively.

### Verified (in a throwaway VM, licensed with the user's own serial)
- Licensing activated through Flash's own flow (a Studio MX 2004 serial).
  The recomp ran against that install, and the real anti-debug check passed.
- The authoring window opens (`docs/screenshots/authoring.png`).
- `tools/vm/make.jsfl` run by the recomp: `harness.swf` SHA-256
  `7C908BA3…EBE81302`, identical to the original Flash.exe's. No original
  Flash.exe was running (`tools/vm/proof.ps1`).

### Changed
- `tools/vm/harness.ps1`: finds the "install Flash Player" prompt by a
  wildcard title search (exact-title FindWindow missed it); `-NoTrial` for a
  licensed install.

## [0.1.0] - 2026-11-12

First bring-up. Pre-alpha: the recomp runs Flash MX 2004's real start-up and
reaches the obfuscated licensing/anti-debug client; it does not yet open the
authoring window.

### Added
- Static recompilation of `Flash.exe` (Flash MX 2004 7.2, VC++ 7.1 / MFC 7.1):
  catalog (34,229 functions, 86.5% of code), lift (120,886 functions, 0
  errors), 32-bit `native32` host, 698 imports bound, 0 unresolved.
- `tools/eh_seeds.py`: seeds every C++ / SEH exception funclet from the
  FuncInfo and scope tables (the catalog misses them; eh32 needs them lifted).
- Host (`src/runtime/host.c`): MSLU (unicows) W-function redirects patched
  into the import thunks the loader-style binding never sees; guest SEH turned
  on; registry-, exit- and SEH-tracing behind `FL_TRACE_*` env vars.
- `tools/vm/serial.ps1`: enters your own serial (from `FLASH_SERIAL`, never stored) on the normal serial-entry page; documented the upgrade-serial result.
- `tools/vm/`: the netlab VM harness â€” install the trial, drive the activation
  dialog's trial flow, make a reference `.fla`/`.swf` with the original
  Flash.exe, run the recomp against the same real licensing service.

### Toolkit (pcrecomp branch `pcrecomp-flashmx`, on `pcrecomp-retailplus`)
- native32/lift: x86 software interrupts (`int 1`, `int n`, n != 3) fault as
  they do on NT (`RECOMP_TRAP`) and are offered to the guest's SEH chain, so
  anti-debug code that traps inside `__try` takes its `__except` block instead
  of looking debugged.
- native32: a guest C++ `throw` that escapes a callback is caught at the
  callback boundary (as WOW64 does when a window procedure lets one out),
  instead of reaching the host and ending the process.

### Known blocker (fixed in 0.2.0)
- At the time, the licensing client's anti-debug check ended the process. The
  cause looked like missing fault-`CONTEXT` state. It was really the
  `__except` blocks being dispatched as functions (see 0.2.0).
