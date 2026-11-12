# Roadmap

## Where it is
Pre-alpha. `flashmxrecomp.exe` runs Flash MX 2004's start-up (MFC/CRT init,
MSLU, registry edition/registration reads, first window-procedure callbacks)
and reaches the SafeCast/FLEXnet licensing client, which runs obfuscated,
code-virtualized anti-debug. It does not open the authoring window.

## The blocker (next, and hardest)
The licensing client uses Microsoft SEH as a VM interpreter: it raises `int 1`
/ `int n` inside `__try`, expecting the NT fault, and drives itself from the
`__except` blocks. The recomp now faults correctly and the guest SEH chain
runs and unwinds, but the obfuscated continuation computes on the fault
`CONTEXT` (registers and `Eip` at the faulting instruction), which the host's
minimal CONTEXT does not fully carry.

To get past it, in order of likely payoff:
1. **Full fault CONTEXT.** Give `seh_records` the complete integer + control
   register state at the trap (it has them: `g_eax..g_edi`, `Eip = t_trap_va`),
   and confirm `Esp`/`Ebp` match what the guest handler expects. The VM reads
   these as its program counter and operands.
2. **`native32_seh_continue` for the MSVC `_except_handler3` path.** Confirm
   the `__except` block is entered through the body's `RECOMP_EH_FRAME`
   landing pad (966 functions got one) and not by the handler returning into
   native CRT. The fault is currently inside `_except_handler3` (sub_00A7F994)
   after `RtlUnwind`.
3. **The VM dispatchers.** sub_00C62EF0 / sub_00C69D60 and the xor-keyed
   dispatchers (sub_00C62380, sub_00C61BF0, ...) are the interpreter. If the
   SEH path alone cannot be made faithful, these may need per-opcode handling.

This is a virtualized-protector problem, not a licensing shortcut. Faking the
service, the license file or the trial check is out of bounds (see the project
rules). A **retail serial** skips the trial anti-debug path and is the
cleaner way in; a contributor with one can likely reach the authoring window
without items 1–3.

## After licensing
4. Authoring window up (MFC main frame, the document/timeline panels).
5. JSFL automation (`fl.createDocument`, `exportSWF`): `tools/vm/make.jsfl`
   already drives the original; point it at the recomp.
6. Turn on `tools/swf_diff.py`: diff the recomp's `.swf`/`.fla` against the
   original's byte-for-byte. The oracle outputs already exist.

## Shared/toolkit work that would help
- The software-interrupt trap and the C++-throw-across-callback fix are on
  `pcrecomp-flashmx`; they are generic and belong on the wide branch once a
  second title exercises them.
