#!/usr/bin/env python3
"""Build the shared studio HDR, wall sign, and floor textures for both demos.

Coordinates in the HDR are Y-up. The panorama is latitude-longitude:
v=0 is up, u=0.5 looks down +Z (the truck's nose in glTF / Godot space).
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "environment"


def _dir(u: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    phi = u * math.tau
    theta = v * math.pi
    y = np.cos(theta)
    horiz = np.sin(theta)
    x = np.sin(phi) * horiz
    z = np.cos(phi) * horiz
    return x, y, z


def _softbox(x, y, z, axis, half_u, half_v, color, gain) -> np.ndarray:
    # axis is the box center direction. half_u / half_v are angular half-sizes.
    ax = np.array(axis, dtype=np.float64)
    ax /= np.linalg.norm(ax)
    up = np.array([0.0, 1.0, 0.0])
    if abs(np.dot(ax, up)) > 0.92:
        up = np.array([0.0, 0.0, 1.0])
    tangent = np.cross(up, ax)
    tangent /= np.linalg.norm(tangent)
    bitangent = np.cross(ax, tangent)
    dirs = np.stack([x, y, z], axis=-1)
    du = dirs @ tangent
    dv = dirs @ bitangent
    facing = np.clip(dirs @ ax, 0.0, 1.0)
    mask = np.exp(-0.5 * ((du / half_u) ** 2 + (dv / half_v) ** 2)) * facing
    col = np.array(color, dtype=np.float64) * gain
    return mask[..., None] * col


def write_hdr(path: Path, width: int = 1024, height: int = 512) -> None:
    v, u = np.mgrid[0:height, 0:width]
    u = (u.astype(np.float64) + 0.5) / width
    v = (v.astype(np.float64) + 0.5) / height
    x, y, z = _dir(u, v)

    # Dark bay, warm horizon so clearcoat has something to catch.
    sky = np.zeros((height, width, 3), dtype=np.float64)
    sky += np.array([0.015, 0.017, 0.022]) * (0.35 + 0.65 * np.clip(y, 0, 1))[..., None]
    sky += np.array([0.045, 0.032, 0.02]) * np.exp(-((y - 0.02) ** 2) / 0.02)[..., None]
    sky += np.array([0.012, 0.011, 0.01]) * np.clip(-y, 0, 1)[..., None]

    boxes = [
        # Key, front-right, warm. Matches the showroom key light.
        ((0.55, 0.62, 0.55), 0.28, 0.16, (1.0, 0.93, 0.82), 18.0),
        # Overhead strip.
        ((0.05, 0.92, 0.15), 0.55, 0.08, (1.0, 0.97, 0.92), 14.0),
        # Cool fill, camera-left.
        ((-0.72, 0.42, 0.38), 0.32, 0.18, (0.62, 0.74, 1.0), 7.5),
        # Rim / hair light behind the truck.
        ((-0.15, 0.55, -0.78), 0.22, 0.12, (1.0, 0.78, 0.55), 9.0),
        # Copper practical on the back wall.
        ((0.0, 0.15, -0.95), 0.18, 0.06, (0.85, 0.42, 0.18), 6.0),
    ]
    for axis, hu, hv, color, gain in boxes:
        sky += _softbox(x, y, z, axis, hu, hv, color, gain)

    _write_rgbe(path, sky)


def _rgbe_pixel(r: float, g: float, b: float) -> bytes:
    v = max(r, g, b)
    if v < 1e-32:
        return b"\x00\x00\x00\x00"
    mantissa, exp = math.frexp(v)
    scale = mantissa * 256.0 / v
    return bytes(
        (
            min(255, int(r * scale)),
            min(255, int(g * scale)),
            min(255, int(b * scale)),
            exp + 128,
        )
    )


def _write_rgbe(path: Path, image: np.ndarray) -> None:
    height, width, _ = image.shape
    header = (
        b"#?RADIANCE\n"
        b"SOFTWARE=truck-app engine-demos\n"
        b"FORMAT=32-bit_rle_rgbe\n"
        b"\n"
        + f"-Y {height} +X {width}\n".encode()
    )
    # Uncompressed RGBE. Godot's HDR loader accepts this when the scanline
    # does not start with the RLE marker.
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            r, g, b = image[y, x]
            pixels += _rgbe_pixel(float(r), float(g), float(b))
    path.write_bytes(header + pixels)


def _font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def write_sign(path: Path) -> None:
    image = Image.new("RGB", (1280, 320), (18, 19, 22))
    draw = ImageDraw.Draw(image)
    draw.rectangle((18, 18, 1262, 302), outline=(166, 98, 52), width=3)
    draw.rectangle((28, 28, 1252, 292), outline=(70, 48, 32), width=1)
    title = _font(92)
    sub = _font(36)
    draw.text((64, 58), "RIDGEHAUL", font=title, fill=(232, 214, 196))
    draw.text((68, 188), "SUMMIT   ·   SHOWROOM", font=sub, fill=(196, 122, 64))
    image.save(path)


def write_lot_sign(path: Path) -> None:
    image = Image.new("RGB", (1280, 320), (28, 26, 22))
    draw = ImageDraw.Draw(image)
    draw.rectangle((18, 18, 1262, 302), outline=(210, 186, 140), width=3)
    title = _font(84)
    sub = _font(34)
    draw.text((64, 62), "MEETUP LOT", font=title, fill=(245, 236, 220))
    draw.text((68, 190), "TWO TRUCKS   ·   ONE BAY", font=sub, fill=(212, 164, 92))
    image.save(path)


def _noise_tile(size: int, base: tuple[int, int, int], amount: float, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, 1.0, (size, size)).astype(np.float32)
    # A few box blurs so the grain reads as concrete, not static.
    for _ in range(3):
        noise = (noise + np.roll(noise, 1, 0) + np.roll(noise, -1, 0) + np.roll(noise, 1, 1) + np.roll(noise, -1, 1)) / 5.0
    # Faint panel seams.
    seams = np.zeros((size, size), dtype=np.float32)
    step = size // 4
    seams[::step, :] -= 0.55
    seams[:, ::step] -= 0.35
    specks = (rng.random((size, size)) > 0.985).astype(np.float32) * 1.4
    field = noise * amount + seams + specks
    color = np.array(base, dtype=np.float32)
    rgb = np.clip(color + field[..., None] * 18.0, 0, 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_hdr(OUT / "studio.hdr")
    write_sign(OUT / "sign.png")
    write_lot_sign(OUT / "lot-sign.png")
    _noise_tile(512, (58, 60, 66), 1.0, 7).save(OUT / "concrete.png")
    _noise_tile(512, (92, 86, 74), 1.15, 11).save(OUT / "asphalt.png")
    print(f"wrote environment textures in {OUT}")


if __name__ == "__main__":
    main()
