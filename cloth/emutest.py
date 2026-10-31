"""Run the real CCloth::simulate from an exe in Unicorn with the Stranger coat.

usage: emutest.py <exe> <strcoat.kfm> <fps> <seconds> [sway]
Root stopped, no wind. Collision bones use the same estimated pose as clothsim.c.
With sway, locked particles and bones move +-sway ft at 1.5 Hz.
"""
import math, re, struct, sys
from unicorn import *
from unicorn.x86_const import *

BASE = 0x400000
THIS = 0x20000000
ORDER = 0x20100000
OUT = 0x20110000
ARGS = 0x20120000
WIND = 0x21000000
STACK = 0x30000000
STOP = 0x40000000
P = lambda i: THIS + 0x398 + i * 0x11c


def load_exe(uc, path):
    d = open(path, "rb").read()
    pe = struct.unpack_from("<I", d, 0x3c)[0]
    n = struct.unpack_from("<H", d, pe + 6)[0]
    uc.mem_map(BASE, 0x2a00000)
    uc.mem_write(BASE, d[:0x400])
    o = pe + 24 + 0xe0
    for i in range(n):
        _, va, rs, rp = struct.unpack_from("<IIII", d, o + 8)
        if rs and rp:
            uc.mem_write(BASE + va, d[rp:rp + rs])
        o += 40


def parse_kfm(path):
    verts, edges, st = [], set(), 0
    for line in open(path, encoding="latin1"):
        line = line.strip()
        if line.startswith("// vertex list"): st = 1; continue
        if line.startswith("// poly list"): st = 2; continue
        if line.startswith("// texture"): break
        if line.startswith("//") or not line: continue
        f = [int(x) for x in re.findall(r"-?\d+", line)]
        if st == 1:
            verts.append([x / 256 for x in f[:3]])
        elif st == 2:
            ids = [f[2 + 3 * i] for i in range(f[1])]
            for i in range(len(ids)):
                a, b = ids[i], ids[(i + 1) % len(ids)]
                edges.add((a, b)); edges.add((b, a))
    return verts, edges


def wf(uc, a, v): uc.mem_write(a, struct.pack("<f", v))
def wi(uc, a, v): uc.mem_write(a, struct.pack("<i", v))
def rf(uc, a, n=1): return struct.unpack(f"<{n}f", uc.mem_read(a, 4 * n))


def bone(uc, i, a, b, r0, r1):
    B = THIS + 0x37b50 + i * 0xac
    d = [b[k] - a[k] for k in range(3)]
    l = math.sqrt(sum(x * x for x in d))
    z = [x / l for x in d]
    s = z[0]
    x = [1 - z[0] * s, -z[1] * s, -z[2] * s]
    m = math.sqrt(sum(c * c for c in x))
    x = [c / m for c in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    wf(uc, B + 0x14, r0); wf(uc, B + 0x18, r1)
    wf(uc, B + 0x38, 1 / r0); wf(uc, B + 0x3c, 1 / r1)
    wf(uc, B + 0x44, l)
    for row in range(3):
        for col, v in enumerate((x[row], y[row], z[row])):
            wf(uc, B + 0x78 + 12 * row + 4 * col, v)
    uc.mem_write(B + 0xa0, struct.pack("<3f", *a))
    return B, a


def main():
    exe, kfm, fps, secs = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
    sway = float(sys.argv[5]) if len(sys.argv) > 5 else 0
    uc = Uc(UC_ARCH_X86, UC_MODE_32)
    load_exe(uc, exe)
    uc.mem_map(THIS, 0x200000)
    uc.mem_map(WIND, 0x200000)
    uc.mem_map(STACK - 0x100000, 0x200000)
    uc.mem_map(STOP, 0x1000)
    uc.mem_write(0x5be368, struct.pack("<I", WIND))
    uc.mem_write(0x1c7070c, struct.pack("<I", 0x1fc00000))
    uc.mem_write(0x1c70710, struct.pack("<I", 0x5f400000))
    verts, edges = parse_kfm(kfm)
    n = len(verts)
    wi(uc, THIS + 0x104, n); uc.mem_write(THIS + 0x10c, struct.pack("<I", OUT))
    uc.mem_write(THIS + 0x3aafc, struct.pack("<I", ORDER))
    for ofs, v in zip(range(0x37b18, 0x37b38, 4), (.25, 32, .95, .025, .5, .5, .05, .15)):
        wf(uc, THIS + ofs, v)
    order = sorted(range(n), key=lambda i: -verts[i][1])
    uc.mem_write(ORDER, struct.pack(f"<{n}i", *order))
    for i, v in enumerate(verts):
        uc.mem_write(P(i), struct.pack("<3f", *v))
        uc.mem_write(P(i) + 0xc0, struct.pack("<3f", *v))
        wi(uc, P(i) + 0x74, 1 if i < 17 else 0)
        wi(uc, P(i) + 0xd8, -1)
        nl = 0
        for b in range(n):
            if (i, b) in edges and verts[i][1] <= verts[b][1]:
                wi(uc, P(i) + 0x34 + 4 * nl, b)
                wf(uc, P(i) + 0x78 + 4 * nl, math.dist(v, verts[b]))
                nl += 1
        wi(uc, P(i) + 0x30, nl)
    poses = [((0, 2.6, 0), (0, 3.4, 0), .6, .5), ((0, 3.3, 0), (0, 3.9, 0), .5, .52), ((0, 3.8, 0), (0, 4.7, 0), .63, .45),
             ((.3, 2.8, 0), (.35, 1.5, 0), .4, .4), ((.35, 1.5, 0), (.35, .2, 0), .4, .4),
             ((-.3, 2.8, 0), (-.35, 1.5, 0), .4, .4), ((-.35, 1.5, 0), (-.35, .2, 0), .4, .4)]
    bones = [bone(uc, i, *p) for i, p in enumerate(poses)]
    wi(uc, THIS + 0x37b4c, len(bones))
    uc.mem_write(ARGS, struct.pack("<6f", 0, 0, 0, 0, 0, 0))

    # x87 setup: one fninit in a stub
    uc.mem_write(STOP + 0x10, b"\xdb\xe3\xf4")
    uc.emu_start(STOP + 0x10, STOP + 0x12)

    t = last_ms = 0.0
    settle = int(secs / 2 * fps)
    frames = int(secs * fps)
    prev, first, lo, hi, total, cnt, maxstep = None, None, None, None, 0.0, 0, 0.0
    for f in range(frames):
        t += 1 / fps
        ms = math.floor(t * 1000)
        dt = (ms - last_ms) / 1000
        last_ms = ms
        if sway:
            ox = sway * math.sin(t * 2 * math.pi * 1.5)
            for B, a in bones:
                uc.mem_write(B + 0xa0, struct.pack("<3f", a[0] + ox, a[1], a[2]))
            for i in range(17):
                wf(uc, P(i), verts[i][0] + ox)
        sp = STACK - 0x1000
        sp -= 28
        uc.mem_write(sp, struct.pack("<IIIIfff", STOP, THIS, ARGS, ARGS + 12, dt, -100.0, 0.0))
        uc.reg_write(UC_X86_REG_ESP, sp)
        uc.reg_write(UC_X86_REG_EBP, 0)
        uc.emu_start(0x436e80, STOP, count=200_000_000)
        out = [x / 256 for x in struct.unpack(f"<{n * 3}i", uc.mem_read(OUT, n * 12))]
        for x in out:
            if not math.isfinite(x) or abs(x) > 1000:
                sys.exit(f"bad output at frame {f}")
        if f >= settle:
            if prev:
                steps = [math.dist(out[3 * i:3 * i + 3], prev[3 * i:3 * i + 3]) for i in range(17, n)]
                total += sum(steps); cnt += len(steps); maxstep = max(maxstep, max(steps))
                lo = [min(a, b) for a, b in zip(lo, out)]
                hi = [max(a, b) for a, b in zip(hi, out)]
            else:
                lo, hi = out[:], out[:]
            prev = out
    rng = [math.dist(lo[3 * i:3 * i + 3], hi[3 * i:3 * i + 3]) for i in range(17, n)]
    print(f"fps {fps:5.0f}  mean_speed {total / cnt * fps:7.4f} ft/s  mean_range {sum(rng) / len(rng):6.4f} ft  "
          f"max_range {max(rng):6.4f} ft  max_frame_move {maxstep:6.4f} ft")


main()
