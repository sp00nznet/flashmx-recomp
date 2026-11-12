# Changelog

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
- `tools/vm/`: the netlab VM harness — install the trial, drive the activation
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

### Known blocker
- The licensing client is code-virtualized anti-debug that uses SEH as its
  interpreter loop. The recomp reproduces the fault and the handler/unwind,
  but the obfuscated `__except` continuation needs exact fault-`CONTEXT`
  state; it takes its tamper path and ends the process. Licensing is never
  faked, so this is where it stops ([README](README.md), "Why it stops").
