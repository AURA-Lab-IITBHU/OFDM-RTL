#!/usr/bin/env python3
"""
Host-side helper for the Zynq OFDM bring-up.

  python check_frame.py gen   qpsk.bin [seed]        # make a 16-byte payload file for the SD card
  python check_frame.py check qpsk.bin frame.bin     # compare the board's frame.bin to the golden

Golden model mirrors the RTL (GUARD=10, DC=32, 4 symbols, CP=16):
  symbol 0 = ZC sync, 1 = all-ones reference, 2 = header (ones),
  symbol 3 = payload with pilots (ones) at (k-9) % 6 == 0.
IFFT is the ideal one with 1/64 scaling, in Q1.15 LSBs.
"""
import sys
import random
import struct
import numpy as np

SC, GUARD, DC, CP, SYM_LEN, N_SYM = 64, 10, 32, 16, 80, 4
TOL = 8                      # LSB; the RTL typically lands within ~2
ONE = 0x7FFF / 32768.0
QP = 0x5A82 / 32768.0        # RTL constant 0x5A82 (23170), not exactly 1/sqrt(2)

ZC_RE = [0x7FFF, 0x9060, 0xFB53, 0x8057, 0x320F, 0xE8C0, 0x2060, 0xE8C0, 0x73E5, 0x42AE,
         0x7EA2, 0xA728, 0xB585, 0x6AC0, 0x7A92, 0x0DFF, 0x73E5, 0x7A92, 0x9060, 0x830F,
         0x6AC0, 0xD6AB, 0x6AC0, 0x830F, 0x9060, 0x7A92, 0x73E5, 0x0DFF, 0x7A92, 0x6AC0,
         0xB585, 0xA728, 0x7EA2, 0x42AE, 0x73E5, 0xE8C0, 0x2060, 0xE8C0, 0x320F, 0x8057,
         0xFB53, 0x9060, 0x7FFF]
ZC_IM = [0x0000, 0x3EA5, 0x7FEA, 0xF6A8, 0x75CD, 0x7DDE, 0x8429, 0x8221, 0x3654, 0x92BD,
         0x12A3, 0xA3DA, 0x97E6, 0x46A0, 0xDB1F, 0x7F3B, 0xC9AB, 0x24E0, 0xC15A, 0xE42B,
         0xB95F, 0x86DB, 0xB95F, 0xE42B, 0xC15A, 0x24E0, 0xC9AB, 0x7F3B, 0xDB1F, 0x46A0,
         0x97E6, 0xA3DA, 0x12A3, 0x92BD, 0x3654, 0x8221, 0x8429, 0x7DDE, 0x75CD, 0xF6A8,
         0x7FEA, 0x3EA5, 0x0000]


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def subcarriers(sym, bits):
    X = np.zeros(SC, dtype=complex)
    for k in range(SC):
        if k == DC or k < GUARD or k >= SC - GUARD:
            continue
        if sym == 0:
            j = k - GUARD - (1 if k > DC else 0)
            X[k] = complex(s16(ZC_RE[j]), s16(ZC_IM[j])) / 32768.0
        elif sym in (1, 2) or (k - (GUARD - 1)) % 6 == 0:
            X[k] = ONE
        else:
            i = (bits >> (2 * k)) & 1
            q = (bits >> (2 * k + 1)) & 1
            X[k] = complex(-QP if i else QP, -QP if q else QP)
    return X


def golden_frame(bits):
    """Returns a (320,) complex array in LSBs: per symbol 16 CP + 64 body."""
    out = []
    for sym in range(N_SYM):
        body = np.fft.ifft(subcarriers(sym, bits)) * 32768.0   # ifft includes 1/64
        out.append(np.concatenate([body[-CP:], body]))
    return np.concatenate(out)


def load_bits(path):
    data = open(path, "rb").read()
    if len(data) != 16:
        sys.exit(f"{path}: expected 16 bytes, got {len(data)}")
    return int.from_bytes(data, "little")


def cmd_gen(path, seed=None):
    rng = random.Random(seed)
    bits = rng.getrandbits(128)
    open(path, "wb").write(bits.to_bytes(16, "little"))
    print(f"wrote {path}: 0x{bits:032x}")


def cmd_check(qpath, fpath):
    bits = load_bits(qpath)
    raw = open(fpath, "rb").read()
    if len(raw) != 320 * 4:
        sys.exit(f"{fpath}: expected 1280 bytes, got {len(raw)}")
    words = struct.unpack("<320I", raw)
    act = np.array([complex(s16(w >> 16), s16(w)) for w in words])
    exp = golden_frame(bits)

    ok = True
    for sym in range(N_SYM):
        a = act[sym * SYM_LEN:(sym + 1) * SYM_LEN]
        e = exp[sym * SYM_LEN:(sym + 1) * SYM_LEN]
        err = max(np.max(np.abs(a.real - e.real)), np.max(np.abs(a.imag - e.imag)))
        cp_ok = all(words[sym * SYM_LEN + j] == words[sym * SYM_LEN + j + SC] for j in range(CP))
        status = "PASS" if (err <= TOL and cp_ok) else "FAIL"
        if status == "FAIL":
            ok = False
        print(f"symbol {sym}: max err {err:5.1f} LSB (tol {TOL}), CP exact: {cp_ok}  [{status}]")
    print("OVERALL:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == "gen":
        cmd_gen(a[1], int(a[2]) if len(a) > 2 else None)
    elif len(a) == 3 and a[0] == "check":
        cmd_check(a[1], a[2])
    else:
        print(__doc__)
        sys.exit(2)
