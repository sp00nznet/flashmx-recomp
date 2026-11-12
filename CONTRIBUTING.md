# Contributing

Issues and pull requests are welcome.

## The one rule

**Nothing from Flash goes in the repository, and no serial ever does.** No
Flash files, no lifted C (`src/recomp/gen/`), no catalogs (`work/`), no
disassembly listings, nothing generated from `Flash.exe`, and no serial
number in a file, a log, a commit or a screenshot (the serial-entry page
shows it). The tool ships; its output is made on each person's machine from
their own licensed copy. `.gitignore` covers the usual paths; check
`git status` before you commit anyway. Screenshots of the recomp running are
fine.

## Before a pull request

1. Build from a clean lift: `py -3 tools\eh_seeds.py`, `py -3 run_lift.py`
   (expected: `0 errors`), then `build.cmd`.
2. Run the conformance harness in the VM (docs/testing.md):
   `tools\vm\harness.ps1` once for the original's reference `.swf`, then
   `tools\vm\proof.ps1`. It must report IDENTICAL. A new behavior comes with
   a JSFL case that shows it.

## Where a fix belongs

- A bug in the lifter, the catalog or the native bridge belongs in
  [pcrecomp](https://github.com/sp00nznet/pcrecomp) (this project builds on
  its `pcrecomp-flashmx` branch), not here.
- A fix to Flash itself is a patch in `run_lift.py` or the host, with a
  comment that says what it fixes and why. Never one that skips or fakes the
  licensing check.
- A wall you got past goes in `docs/bringup.md`: what it looked like, what it
  was, what moved it.
