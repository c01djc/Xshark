#!/usr/bin/env python3
"""Recolor Wireshark shark-fin icons from blue/green to red (GM build)."""

from __future__ import annotations

import io
import struct
import sys
from pathlib import Path

from PIL import Image
import numpy as np
from colorsys import rgb_to_hsv, hsv_to_rgb


ICON_DIR = Path(__file__).resolve().parents[1] / "resources" / "icons"
UPSTREAM_PREFIX = "_upstream_"

PNG_NAMES = [
    "wsicon16.png", "wsicon24.png", "wsicon32.png", "wsicon48.png", "wsicon64.png", "wsicon256.png",
    "wsiconcap16.png", "wsiconcap24.png", "wsiconcap32.png", "wsiconcap48.png", "wsiconcap64.png", "wsiconcap256.png",
    "wsicon-ask.png",
]

ICO_PNG_SIZES = [16, 24, 32, 48, 64, 256]


def recolor_to_red(img: Image.Image) -> Image.Image:
    """Map saturated blue/green shark branding pixels to red; keep white fin."""
    rgba = np.array(img.convert("RGBA"), dtype=np.float32)
    rgb = rgba[:, :, :3] / 255.0
    alpha = rgba[:, :, 3]

    flat = rgb.reshape(-1, 3)
    aflat = alpha.reshape(-1)
    out = np.zeros_like(flat)

    for idx, (r, g, b) in enumerate(flat):
        if aflat[idx] < 8:
            out[idx] = [0.0, 0.0, 0.0]
            continue
        h, s, v = rgb_to_hsv(r, g, b)
        if s < 0.12:
            out[idx] = [r, g, b]
        else:
            out[idx] = hsv_to_rgb(0.0, s, v)

    result = np.zeros_like(rgba)
    result[:, :, :3] = (out.reshape(rgb.shape) * 255.0)
    result[:, :, 3] = alpha
    return Image.fromarray(np.clip(result, 0, 255).astype(np.uint8))


def bmp_ico_chunk_to_rgba(chunk: bytes) -> Image.Image:
    """Decode a BMP payload stored inside an ICO file."""
    im = Image.open(io.BytesIO(chunk))
    w, full_h = im.size
    h = full_h // 2
    xor = im.crop((0, 0, w, h)).convert("RGBA")
    and_mask = im.crop((0, h, w, full_h)).convert("L")
    rgba = xor.copy()
    rgba.putalpha(and_mask)
    return rgba


def extract_ico_frames(ico_path: Path) -> list[tuple[int, Image.Image]]:
    data = ico_path.read_bytes()
    count = struct.unpack_from("<H", data, 4)[0]
    offset = 6
    frames: list[tuple[int, Image.Image]] = []
    for _ in range(count):
        w, h, _colors, _reserved, _planes, _bpp, size, imgoff = struct.unpack_from("<BBBBHHII", data, offset)
        offset += 16
        size_px = w or 256
        chunk = data[imgoff:imgoff + size]
        if chunk.startswith(b"\x89PNG"):
            img = Image.open(io.BytesIO(chunk)).convert("RGBA")
        else:
            img = bmp_ico_chunk_to_rgba(chunk)
        frames.append((size_px, img))
    return frames


def build_ico_from_png_images(images: list[tuple[int, Image.Image]], path_out: Path) -> None:
    """Build a Vista-style ICO with embedded PNGs at every resolution."""
    images = sorted(images, key=lambda item: item[0])
    png_chunks: list[bytes] = []
    for _size, image in images:
        buf = io.BytesIO()
        image.convert("RGBA").save(buf, format="PNG", optimize=True)
        png_chunks.append(buf.getvalue())

    count = len(png_chunks)
    header = struct.pack("<HHH", 0, 1, count)
    entries: list[bytes] = []
    data_offset = 6 + 16 * count
    current = data_offset
    for (size_px, _), png in zip(images, png_chunks):
        entry_w = 0 if size_px >= 256 else size_px
        entry_h = entry_w
        entries.append(struct.pack("<BBBBHHII", entry_w, entry_h, 0, 0, 1, 32, len(png), current))
        current += len(png)

    with path_out.open("wb") as fh:
        fh.write(header)
        for entry in entries:
            fh.write(entry)
        for png in png_chunks:
            fh.write(png)


def recolor_wireshark_ico(icon_dir: Path) -> None:
    """Build wireshark.ico from recolored wsicon PNGs at every standard size."""
    frames: list[tuple[int, Image.Image]] = []
    for size_px in ICO_PNG_SIZES:
        png = icon_dir / f"wsicon{size_px}.png"
        if not png.exists():
            print(f"skip wireshark.ico: missing {png.name}")
            return
        frames.append((size_px, Image.open(png).convert("RGBA")))

    out = icon_dir / "wireshark.ico"
    build_ico_from_png_images(frames, out)
    print(f"updated wireshark.ico ({len(frames)} sizes, {out.stat().st_size} bytes)")


def main() -> int:
    icon_dir = ICON_DIR
    if len(sys.argv) > 1:
        icon_dir = Path(sys.argv[1])

    for name in PNG_NAMES:
        src = icon_dir / f"{UPSTREAM_PREFIX}{name}"
        if not src.exists():
            src = icon_dir / name
        if not src.exists():
            print(f"skip missing {name}")
            continue
        dst = icon_dir / name
        recolor_to_red(Image.open(src)).save(dst)
        print(f"updated {dst.name}")

    recolor_wireshark_ico(icon_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
