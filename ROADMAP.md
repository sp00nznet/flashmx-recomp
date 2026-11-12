# Roadmap

## Where it is
v0.2.0, alpha. With a licensed install, `flashmxrecomp.exe` passes Flash's
own licensing and anti-debug checks, opens the authoring window, and runs JSFL
end to end. A published `.swf` is byte-identical to the original's (one test
document: shapes, text, two keyframes, a frame script).

## Next
1. **A wider conformance corpus.** Today it's one document. Add JSFL cases
   for: symbols and the library, tweens (motion/shape), bitmaps and sounds,
   fonts (embedded and device), ActionScript 2.0 classes, components, and
   publish settings (Flash 6/7 player, compression, protect). Diff each
   `.swf` against the original's.
2. **`.fla` comparison.** The `.fla` embeds a save timestamp. Compare it
   with that field masked, or round-trip it (open in the original, re-export).
3. **Interactive use.** The window, menus and tools have only been seen. Drive
   them: draw, open/save dialogs, Test Movie (it loads the player).
4. **The trial path.** It runs the same anti-debug code as the licensed path,
   which now passes, so the trial should get through too. Not re-tested yet.
5. **Callback C++ throws.** The splash/WM_SIZE handler lets an `int` throw
   escape a window procedure. The host now ends that callback as Windows
   does. Check that nothing visible depends on it.

## Toolkit work this proved out
- On `pcrecomp-flashmx`: x86 software interrupts → guest SEH (`RECOMP_TRAP`),
  and C++ throws ended at a callback boundary. Both are generic. They belong on
  the wide branch once a sibling title confirms them.
- The fix that got licensing through was a lift-driver rule: keep
  `__except`/catch continuations out of dispatch. SWGB's driver already does
  it. It should move into pcrecomp's shared driver, so every MSVC SEH title
  gets it by default.
