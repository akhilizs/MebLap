"""Generates the 1024x1024 app icon (Lebanese flag colours, cedar and road) with no dependencies."""
import struct, zlib, sys

S = 1024
RED, WHITE, GREEN, ROAD, LINE = (237, 28, 36), (255, 255, 255), (0, 166, 81), (60, 60, 67), (255, 204, 0)

def tri(px, py, a, b, c):
    def s(p1, p2, p3):
        return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
    d1, d2, d3 = s((px, py), a, b), s((px, py), b, c), s((px, py), c, a)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))

# Cedar: stacked triangles plus trunk
tiers = [((512, 190), (330, 420), (694, 420)),
         ((512, 300), (280, 560), (744, 560)),
         ((512, 430), (230, 700), (794, 700))]

def pixel(x, y):
    # Road sweeping up from the bottom (perspective trapezoid)
    if y > 700:
        t = (y - 700) / 324
        half = 60 + 300 * t
        if abs(x - 512) < half:
            if abs(x - 512) < 6 + 10 * t and int((y - 700) / 40) % 2 == 0:
                return LINE
            return ROAD
    if 470 <= x <= 554 and 690 <= y <= 780:
        return (110, 70, 40)
    for a, b, c in tiers:
        if tri(x, y, a, b, c):
            return GREEN
    if y < 170 or y > 854:
        return RED
    return WHITE

rows = bytearray()
for y in range(S):
    rows.append(0)
    for x in range(S):
        rows.extend(pixel(x, y))

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
