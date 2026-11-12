#!/usr/bin/env python3
"""Conformance check: the recomp's .swf must match the original Flash.exe's.

Both files are made in the throwaway VM by tools/vm/make.jsfl: the original's
with tools/vm/harness.ps1, the recomp's with tools/vm/proof.ps1. This
compares them byte for byte and, when they differ, reports the SWF header and
the first differing tag, so a mismatch points at what was exported wrong.

    py -3 tools/swf_diff.py original/harness.swf recomp/harness.swf
    py -3 tools/swf_diff.py --selftest

Exit code 0: IDENTICAL; 1: different; 2: a file is missing.
"""
import struct
import sys
import zlib


def body(data):
    """The uncompressed SWF (header + tags), for both FWS and CWS files."""
    if data[:3] == b'CWS':
        return b'FWS' + data[3:8] + zlib.decompress(data[8:])
    return data


def tags(swf):
    """(offset, code, length) of each tag, after the header's frame rect."""
    nbits = swf[8] >> 3
    pos = 8 + (5 + 4 * nbits + 7) // 8 + 4          # rect, frame rate, frame count
    out = []
    while pos + 2 <= len(swf):
        hdr = struct.unpack_from('<H', swf, pos)[0]
        code, ln, start = hdr >> 6, hdr & 0x3F, pos + 2
        if ln == 0x3F:
            ln = struct.unpack_from('<I', swf, start)[0]
            start += 4
        out.append((pos, code, ln))
        pos = start + ln
        if code == 0:
            break
    return out


def compare(a, b):
    if a == b:
        return 'IDENTICAL (%d bytes)' % len(a)
    sa, sb = body(a), body(b)
    msg = ['DIFFERENT: %d vs %d bytes' % (len(a), len(b))]
    if sa[:3] != sb[:3] or sa[3] != sb[3]:
        msg.append('  header: %r v%d vs %r v%d' % (sa[:3], sa[3], sb[:3], sb[3]))
    for (oa, ca, la), (ob, cb, lb) in zip(tags(sa), tags(sb)):
        if (ca, la) != (cb, lb) or sa[oa:oa + la + 6] != sb[ob:ob + lb + 6]:
            msg.append('  first differing tag: code %d len %d at 0x%X vs code %d len %d at 0x%X'
                       % (ca, la, oa, cb, lb, ob))
            break
    return '\n'.join(msg)


def _selftest():
    rect = bytes(1)                                        # nbits 0: one zero byte
    end = struct.pack('<H', 0)
    swf = b'FWS\x07' + struct.pack('<I', 0) + rect + b'\x00\x0c\x01\x00' + end
    swf = swf[:4] + struct.pack('<I', len(swf)) + swf[8:]
    assert compare(swf, swf).startswith('IDENTICAL')
    assert tags(swf) == [(len(swf) - 2, 0, 0)]
    other = swf[:-2] + struct.pack('<H', (9 << 6) | 3) + b'\x01\x02\x03' + end
    assert compare(swf, other).startswith('DIFFERENT')
    cws = b'CWS' + swf[3:8] + zlib.compress(swf[8:])
    assert body(cws) == swf
    print('swf_diff selftest: ok')


def main(argv):
    if argv[1:] == ['--selftest']:
        _selftest()
        return 0
    if len(argv) != 3:
        print(__doc__)
        return 2
    try:
        a, b = (open(p, 'rb').read() for p in argv[1:])
    except OSError as e:
        print('MISSING: %s' % e)
        return 2
    r = compare(a, b)
    print(r)
    return 0 if r.startswith('IDENTICAL') else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
