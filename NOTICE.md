# Notice

The MIT license in [LICENSE](LICENSE) covers what is ours in this repository:
the host, the lift driver, the setup scripts, the tools (including the VM
scripts in `tools/vm/`) and the documentation. It does not cover Flash.

*Macromedia Flash MX 2004* is © 2004 Macromedia, Inc. (now Adobe), and is not
ours to license. Its executables, DLLs, licensing files and data are not in
this repository and are excluded by `.gitignore`. Neither is any serial
number: you supply your own, at run time.

- You need your own installed and licensed copy of Flash MX 2004 to use any
  of this. Setup copies its `Flash.exe` into `work/`; the pipeline reads it
  from there.
- Lifted code is a derivative work of the binary it came from. Anything the
  pipeline writes into `work/` or `src/recomp/gen*/` carries whatever license
  the original carries, not this one. The MIT grant stops at our own work.
- The licensing component (Macrovision SafeCast / FLEXnet) is the vendor's.
  This project does not reproduce, bypass or disable it; the recomp runs it.

There is no third-party code in this repository. The host derives from our
own MIT recomps (Retail Plus Lite, AmazingMIDI, MechWarrior 3) and builds on
[pcrecomp](https://github.com/sp00nznet/pcrecomp) (MIT), fetched by setup.
