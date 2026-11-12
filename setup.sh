#!/bin/sh
# Flash MX 2004 recomp: there is no Linux or macOS build yet.
# The recomp runs against a licensed Windows install of Flash MX 2004 (its
# licensing service is set up only by Flash's own Windows installer), and the
# host is MSVC x86 inline assembly. Use Setup.cmd in a Windows VM.
echo "Flash MX 2004 recomp: no Linux/macOS build yet. It needs a licensed Windows install of Flash MX 2004;"
echo "run Setup.cmd in a Windows VM (README, Getting Started)."
exit 1
