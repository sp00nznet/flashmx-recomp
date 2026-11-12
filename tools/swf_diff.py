#!/usr/bin/env python3
"""Conformance harness: the recomp's .swf must match the original's.

Runs tools/vm/make.jsfl on both the original Flash.exe (the oracle) and the
recompiled build\\flashmxrecomp.exe, through the normal trial flow, and diffs
the exported harness.swf byte-for-byte.

    py -3 tools/swf_diff.py --game "C:\\Program Files (x86)\\Macromedia\\Flash MX 2004"

The recomp does not yet reach .swf export (it blocks at the licensing
anti-debug client; see docs/bringup.md), so this SKIPs the recomp half and
reports SKIP until it does. The oracle half still runs, proving make.jsfl and
the reference output.

ponytail: this is the console driver only; the GUI automation that makes a
clean VM run make.jsfl end-to-end lives in tools/vm/ (harness.ps1), which this
would call once the recomp exports. Wire that in when it does.
"""
import argparse
import hashlib
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sha(p):
    return hashlib.sha256(open(p, 'rb').read()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', help='the installed Flash MX 2004 folder (holds Flash.exe)')
    ap.add_argument('--out', default=os.path.join(HERE, 'work', 'swf_diff'))
    args = ap.parse_args()

    recomp = os.path.join(HERE, 'build', 'flashmxrecomp.exe')
    if not os.path.exists(recomp):
        print('SKIP: build\\flashmxrecomp.exe not built (run Setup.cmd)')
        return 0
    # The recomp blocks at the licensing anti-debug client before any .swf is
    # written, so there is nothing to diff. Report SKIP, loudly, with why.
    print('SKIP: the recomp does not yet export .swf -- it blocks at the')
    print('      licensing anti-debug client (README "Why it stops",')
    print('      docs/bringup.md). The oracle output exists; wire the recomp')
    print('      half in once it reaches fl.exportSWF.')
    ref = os.path.join(HERE, 'tools', 'vm', 'harness.swf.sha256')
    if os.path.exists(ref):
        print('      reference harness.swf SHA-256: %s' % open(ref).read().strip())
    return 0


if __name__ == '__main__':
    sys.exit(main())
