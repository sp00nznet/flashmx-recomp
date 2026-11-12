# Building

`Setup.cmd` runs exactly these steps; this is the same by hand. Windows only:
the host is MSVC x86 inline assembly, and Flash needs its Windows licensing
service.

## Prerequisites

- Flash MX 2004 7.2, installed and activated with your own serial (or the
  trial), in a throwaway Windows VM (README, Getting Started).
- Python 3.10 or newer (`py -3`), with `pip install --user pefile capstone`.
- Visual Studio 2022 (or its Build Tools) with the C++ x86 tools; CMake and
  Ninja come with that workload.
- pcrecomp beside this folder, on branch **`pcrecomp-flashmx`**:
  `git clone -b pcrecomp-flashmx https://github.com/sp00nznet/pcrecomp ..\pcrecomp`
  (or set `PCRECOMP` to a checkout). `main` lacks the trap-to-SEH and
  callback-throw changes this needs.

## Steps

```
copy "C:\Program Files (x86)\Macromedia\Flash MX 2004\Flash.exe" work\
py -3 ..\pcrecomp\tools\disasm\disasm32.py work\Flash.exe -o work\functions.json   # ~25 min
py -3 tools\eh_seeds.py                                                            # exception funclets
py -3 run_lift.py                                                                  # ~10 min, 0 errors -> src\recomp\gen\
build.cmd                                                                          # 30-60 min -> build\flashmxrecomp.exe
build\flashmxrecomp.exe --run --game "C:\Program Files (x86)\Macromedia\Flash MX 2004"
```

`--args script.jsfl` passes a JSFL script to Flash. The 64-bit-hosted
compiler (`amd64_x86`) is used because the 32-bit `cl.exe` runs out of heap
on a 400-function chunk (C1002). The C runtime is linked statically, since a
test VM has no 32-bit VC++ redistributable.

`src/recomp/gen/` and `work/` are generated from your copy and gitignored;
never commit them.
