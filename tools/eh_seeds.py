#!/usr/bin/env python3
"""Seeds for run_lift.py: every C++ EH funclet in Flash.exe.

MSVC's catch blocks and unwind (destructor) funclets are only reached
through the FuncInfo tables, never by a call, so the catalog misses many of
them and eh32 then finds a catch it cannot run ("funclet ... is not
lifted"). Each frame handler is a stub `mov eax, FuncInfo; jmp
__CxxFrameHandler`; this reads every FuncInfo and lists its funclets.

    py -3 tools/eh_seeds.py            # -> work/seeds.json (run_lift.py reads it)
"""
import collections
import json
import os
import struct

import pefile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pe = pefile.PE(os.path.join(ROOT, 'work', 'Flash.exe'))
B = pe.OPTIONAL_HEADER.ImageBase
img = pe.get_memory_mapped_image()
text = [s for s in pe.sections if s.Name.startswith(b'.text')][0]
lo, hi = B + text.VirtualAddress, B + text.VirtualAddress + text.Misc_VirtualSize
u32 = lambda va: struct.unpack_from('<I', img, va - B)[0]  # noqa: E731
MAGIC = {0x19930520, 0x19930521, 0x19930522}

# mov eax, imm32 (B8) ; jmp rel32 (E9): the jmp target shared by most is __CxxFrameHandler
stubs, targets = [], collections.Counter()
t0 = text.VirtualAddress
for o in range(t0, t0 + text.Misc_VirtualSize - 10):
    if img[o] == 0xB8 and img[o + 5] == 0xE9:
        fi = struct.unpack_from('<I', img, o + 1)[0]
        if B <= fi < B + len(img) - 4 and u32(fi) in MAGIC:
            tgt = B + o + 10 + struct.unpack_from('<i', img, o + 6)[0]
            stubs.append(fi)
            targets[tgt] += 1
seeds = set()
for fi in set(stubs):
    nstate, unwind, ntry, trymap = u32(fi + 4), u32(fi + 8), u32(fi + 12), u32(fi + 16)
    for i in range(nstate if unwind else 0):
        act = u32(unwind + 8 * i + 4)
        if lo <= act < hi:
            seeds.add(act)
    for t in range(ntry if trymap else 0):
        tb = trymap + 20 * t
        ncatch, harr = u32(tb + 12), u32(tb + 16)
        for c in range(ncatch):
            h = u32(harr + 16 * c + 12)
            if lo <= h < hi:
                seeds.add(h)
json.dump(sorted(seeds), open(os.path.join(ROOT, 'work', 'seeds.json'), 'w'))
print('%d FuncInfo, %d funclets, handler %s' % (len(set(stubs)), len(seeds),
                                                ' '.join('0x%08X' % t for t, _ in targets.most_common(2))))
