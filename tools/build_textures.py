"""Generate the cartoon sea texture: assets/Textures/SeaCartoon.png.

Usage: python tools/build_textures.py

A seamless 512x512 pattern of soft white caustic lines on a transparent
background, in the toon style of cartoon oceans: the edges of a jittered
Voronoi grid, wobbled, with varying width and broken into strokes. Every
distortion uses whole periods over the tile, so it repeats without seams.
The water color comes from each island's ambience, so the texture only adds
the light lines. Upload it to Roblox (Asset Manager or the
Creator Dashboard) and put its id in World.Sea.textureId.

Pure Python (no image libraries): writes the PNG with zlib.
"""
import math
import pathlib
import random
import struct
import zlib

PROJECT = pathlib.Path(__file__).resolve().parent.parent
OUT = PROJECT / "assets" / "Textures" / "SeaCartoon.png"

SIZE = 512
CELLS = 5  # cells per side; the pattern repeats exactly at the edges
LINE = 0.05  # average line half width, in cell units
SOFT = 0.035  # edge softness, in cell units
WARP = 0.22  # wobble of the lines, in cell units
SEED = 7
TAU = 2 * math.pi


def write_png(path: pathlib.Path, width: int, height: int, rgba: bytearray) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)  # no filter
        rows += rgba[y * stride:(y + 1) * stride]
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    rng = random.Random(SEED)
    points = [[(i + 0.15 + 0.7 * rng.random(), j + 0.15 + 0.7 * rng.random()) for j in range(CELLS)] for i in range(CELLS)]
    rgba = bytearray(SIZE * SIZE * 4)

    def periodic(u: float, v: float, a: int, b: int, phase: float) -> float:
        """Smooth wave with whole periods over the tile, in -1..1."""
        return math.sin(TAU * (a * u + b * v) / CELLS + phase)

    for py in range(SIZE):
        v0 = (py + 0.5) / SIZE * CELLS
        for px in range(SIZE):
            u0 = (px + 0.5) / SIZE * CELLS
            # Wobble the lines like moving water.
            u = u0 + WARP * (periodic(u0, v0, 0, 3, 0.4) + 0.5 * periodic(u0, v0, 2, 5, 1.3))
            v = v0 + WARP * (periodic(u0, v0, 3, 0, 2.1) + 0.5 * periodic(u0, v0, 5, 2, 0.7))
            ci, cj = math.floor(u), math.floor(v)
            first = second = math.inf
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    i, j = ci + di, cj + dj
                    # Wrap cells so the texture tiles seamlessly.
                    pxp, pyp = points[i % CELLS][j % CELLS]
                    pxp += (i - i % CELLS)
                    pyp += (j - j % CELLS)
                    d = math.hypot(u - pxp, v - pyp)
                    if d < first:
                        first, second = d, first
                    elif d < second:
                        second = d
            edge = second - first  # 0 on the boundary between two cells
            width = LINE * (0.55 + 0.45 * (periodic(u0, v0, 4, 1, 0.2) + 1))
            alpha = 1 - min(1.0, max(0.0, (edge - width) / SOFT))
            # Break the lines into strokes.
            gaps = periodic(u0, v0, 7, 3, 0.9) + periodic(u0, v0, -2, 8, 2.4)
            alpha *= min(1.0, max(0.0, (gaps + 0.6) / 0.6))
            offset = (py * SIZE + px) * 4
            rgba[offset:offset + 4] = bytes((255, 255, 255, int(alpha * 235)))
    write_png(OUT, SIZE, SIZE, rgba)
    print(f"Wrote {OUT.relative_to(PROJECT)}")


if __name__ == "__main__":
    main()
