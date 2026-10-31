"""Assemble cave.s, write a patched copy of nocturne.exe, and print the data for NocturneClockFix.ps1.

usage: build.py <input exe> <output exe>
Input must be the clock-patched exe (MD5 2d094a32...). The clock patch is not part of this patch.
"""
import hashlib, os, struct, subprocess, sys, tempfile

LLVM = r"C:\Program Files\LLVM\bin"
HERE = os.path.dirname(os.path.abspath(__file__))
CAVE_VA = 0x574c20
CAVE_END = 0x574e00
AUTO_DELTA = 0x400000 + 0x1000 - 0x400   # VA - file offset in AUTO
CLOCK_PATCHED_MD5 = "2d094a32c4416e1a19f30c1aa8bb6067"
HOOKS = [  # VA, original bytes, cave entry offset
    (0x437183, bytes.fromhex("8b551c528d44240c50"), 0),
    (0x43774c, bytes.fromhex("8bb704010000"), 5),
]


def assemble():
    tmp = tempfile.mkdtemp()
    obj, elf, raw = (os.path.join(tmp, n) for n in ("cave.o", "cave.elf", "cave.bin"))
    subprocess.check_call([os.path.join(LLVM, "clang.exe"), "--target=i386-none-elf", "-c",
                           os.path.join(HERE, "cave.s"), "-o", obj])
    subprocess.check_call([os.path.join(LLVM, "ld.lld.exe"), f"-Ttext=0x{CAVE_VA:x}", "-e", "_start",
                           "--oformat=binary", obj, "-o", raw])
    return open(raw, "rb").read()


def main(src, dst):
    data = bytearray(open(src, "rb").read())
    md5 = hashlib.md5(data).hexdigest()
    if md5 != CLOCK_PATCHED_MD5:
        sys.exit(f"unexpected input MD5 {md5}")
    cave = assemble()
    if CAVE_VA + len(cave) > CAVE_END:
        sys.exit(f"cave too large: {len(cave)} bytes")
    cave_ofs = CAVE_VA - AUTO_DELTA
    if any(data[cave_ofs:CAVE_END - AUTO_DELTA]):
        sys.exit("cave area is not empty")
    data[cave_ofs:cave_ofs + len(cave)] = cave
    for va, orig, entry in HOOKS:
        ofs = va - AUTO_DELTA
        if data[ofs:ofs + len(orig)] != orig:
            sys.exit(f"unexpected bytes at 0x{va:x}")
        rel = CAVE_VA + entry - (va + 5)
        data[ofs:ofs + len(orig)] = b"\xe9" + struct.pack("<i", rel) + b"\x90" * (len(orig) - 5)
    open(dst, "wb").write(data)
    print("$ClothCave:", cave.hex().upper())
    for va, orig, entry in HOOKS:
        ofs = va - AUTO_DELTA
        print(f"hook 0x{ofs:X}: {orig.hex().upper()} -> {data[ofs:ofs + len(orig)].hex().upper()}")
    print(f"cave {len(cave)} bytes, MD5 {hashlib.md5(data).hexdigest()}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
