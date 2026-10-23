"""Builds the UI icons (assets/Icons/<Name>.png, 160 x 160, transparent).

The drawings are the SVGs of the approved Figma design (page "Componentes",
Icon/<Name>). They are rendered with headless Chrome on a transparent page:
Figma's own PNG export kept the page's white background, which shows as a
white box in Roblox. Upload the PNGs to Roblox and put their ids in
src/client/UI/Icons.luau.

    python tools/build_icons.py            # render every icon
    python tools/build_icons.py --check    # fail if an icon is missing or not transparent

Needs Google Chrome (path in the CHROME environment variable if it is not in
the default location).
"""

import math
import os
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "Icons")
SIZE = 160
CHROME = os.environ.get("CHROME", r"C:\Program Files\Google\Chrome\Application\chrome.exe")


def gear():
    points = []
    for tooth in range(8):
        base = tooth * 45
        for angle, radius in ((base - 11, 18), (base + 11, 18), (base + 14, 13.5), (base + 31, 13.5)):
            t = math.radians(angle)
            points.append(f"{20 + radius * math.cos(t):.2f} {20 + radius * math.sin(t):.2f}")
    return (
        f'<path fill-rule="evenodd" d="M{"L".join(points)}Z M26 20A6 6 0 1 0 14 20A6 6 0 1 0 26 20Z" '
        'fill="#D9CCF0" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/>'
    )


# 40 x 40 viewBox drawings, exactly as in the Figma design.
ICONS = {
    "Yen": '<circle cx="20" cy="20" r="17" fill="#FFC21A" stroke="#000" stroke-width="2.5"/><circle cx="20" cy="20" r="12.5" fill="none" stroke="#FFE680" stroke-width="2"/><path d="M14 11L20 20L26 11M20 20V30M15 21H25M15 25.5H25" fill="none" stroke="#7A4A00" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
    "Gem": '<path d="M10 6H30L38 16L20 36L2 16Z" fill="#3FD8FF" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/><path d="M2 16H38M14 6L10 16L20 36L30 16L26 6" fill="none" stroke="#0A6FA8" stroke-width="1.6"/><path d="M12 9L8 15H15Z" fill="#C9F6FF"/>',
    "Clover": '<path d="M20 26Q22 33 27 37" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/><g fill="#52E04A" stroke="#000" stroke-width="2.5"><circle cx="20" cy="11" r="7.5"/><circle cx="29" cy="19" r="7.5"/><circle cx="20" cy="27" r="7.5"/><circle cx="11" cy="19" r="7.5"/></g><circle cx="20" cy="19" r="3.5" fill="#2E9E2A"/>',
    "Bolt": '<path d="M23 3L8 23H18L15 37L32 16H21Z" fill="#FFD21A" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/><path d="M21 8L12 21H17" fill="none" stroke="#FFF3A0" stroke-width="2" stroke-linecap="round"/>',
    "Bag": '<path d="M15 9Q15 3 20 3Q25 3 25 9" fill="none" stroke="#000" stroke-width="2.5"/><path d="M8 15Q8 8 14 8H26Q32 8 32 15V36H8Z" fill="#D7B4FF" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/><rect x="13" y="20" width="14" height="8" rx="2" fill="#FFFFFF" stroke="#000" stroke-width="2"/>',
    "Gear": gear(),
    "Sword": '<path d="M30 4H36V10L18 28L12 22Z" fill="#E8F0FF" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/><path d="M9 21L19 31M12 28L5 35" stroke="#000" stroke-width="4.5" stroke-linecap="round"/><path d="M9.5 21.5L18.5 30.5" stroke="#FFC21A" stroke-width="2" stroke-linecap="round"/>',
    "Music": '<path d="M16 30V8L32 4V25" fill="none" stroke="#000" stroke-width="3"/><ellipse cx="12" cy="30" rx="5.5" ry="4.5" fill="#D7B4FF" stroke="#000" stroke-width="2.5"/><ellipse cx="28" cy="25" rx="5.5" ry="4.5" fill="#D7B4FF" stroke="#000" stroke-width="2.5"/>',
    "Speaker": '<path d="M5 15H12L21 7V33L12 25H5Z" fill="#D7B4FF" stroke="#000" stroke-width="2.5" stroke-linejoin="round"/><path d="M26 13Q30 20 26 27M31 9Q38 20 31 31" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/>',
    "Clock": '<circle cx="20" cy="21" r="15" fill="#FFFFFF" stroke="#000" stroke-width="2.5"/><path d="M20 12V22L26 26" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/>',
    "Check": '<circle cx="20" cy="20" r="17" fill="#7BE000" stroke="#000" stroke-width="3"/><path d="M11 20L17.5 26.5L29 14" fill="none" stroke="#000" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><path d="M11 20L17.5 26.5L29 14" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>',
}


def render(name, body, workdir):
    html = os.path.join(workdir, f"{name}.html")
    with open(html, "w", encoding="utf-8") as f:
        f.write(
            '<!doctype html><html><body style="margin:0;background:transparent;overflow:hidden">'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 40 40" '
            f'style="display:block">{body}</svg></body></html>'
        )
    out = os.path.join(OUT, f"{name}.png")
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--default-background-color=00000000",
            f"--window-size={SIZE},{SIZE}",
            f"--screenshot={out}",
            "file:///" + html.replace("\\", "/"),
        ],
        check=True,
        capture_output=True,
    )
    return out


def read_pixels(path):
    """(width, height, alpha of every pixel) of an 8-bit RGB/RGBA PNG."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos : pos + 8])
        chunk = data[pos + 8 : pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", chunk[:10])
            if depth != 8 or color not in (2, 6):
                raise ValueError(f"{path}: unsupported PNG (depth {depth}, color {color})")
            channels = 4 if color == 6 else 3
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    previous = bytearray(stride)
    alphas = []
    for y in range(height):
        kind = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = previous[i]
            c = previous[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        alphas.extend(line[x * channels + 3] if channels == 4 else 255 for x in range(width))
        previous = line
    return width, height, alphas


def problems():
    found = []
    for name in ICONS:
        path = os.path.join(OUT, f"{name}.png")
        if not os.path.exists(path):
            found.append(f"{name}: missing")
            continue
        width, height, alphas = read_pixels(path)
        border = [alphas[x] for x in range(width)]
        border += [alphas[(height - 1) * width + x] for x in range(width)]
        border += [alphas[y * width] for y in range(height)] + [alphas[y * width + width - 1] for y in range(height)]
        if (width, height) != (SIZE, SIZE):
            found.append(f"{name}: {width} x {height}, expected {SIZE} x {SIZE}")
        if any(alpha > 0 for alpha in border):
            found.append(f"{name}: the background is not transparent")
    return found


def main():
    if "--check" not in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        with tempfile.TemporaryDirectory() as workdir:
            for name, body in ICONS.items():
                print("built", render(name, body, workdir))
    issues = problems()
    for issue in issues:
        print("FAIL", issue)
    if issues:
        sys.exit(1)
    print(f"OK: {len(ICONS)} icons, {SIZE} x {SIZE}, transparent")


if __name__ == "__main__":
    main()
