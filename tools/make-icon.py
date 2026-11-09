#!/usr/bin/env python3
# Rimward -- Copyright (C) 2026 Pascal J. Bourguignon -- AGPL-3.0-or-later.
# Renders the 1024x1024 app icon: a glowing hexagonal well and the ship.
# Usage: python3 tools/make-icon.py App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 2  # supersampling
W = SIZE * SCALE
C = W / 2


def regular(n, r, rot, cx=C, cy=C):
    return [(cx + r * math.cos(rot + 2 * math.pi * k / n), cy + r * math.sin(rot + 2 * math.pi * k / n))
            for k in range(n)]


def strokes(draw, color, width):
    outer = regular(6, W * 0.40, math.pi / 2)
    inner = regular(6, W * 0.07, math.pi / 2, C, C - W * 0.03)
    draw.line(outer + [outer[0]], fill=color, width=width, joint="curve")
    draw.line(inner + [inner[0]], fill=color, width=width, joint="curve")
    for k in range(6):
        for f in (0.0, 1 / 3, 2 / 3):
            a = outer[k]
            b = outer[(k + 1) % 6]
            p = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
            ai = inner[k]
            bi = inner[(k + 1) % 6]
            q = (ai[0] + (bi[0] - ai[0]) * f, ai[1] + (bi[1] - ai[1]) * f)
            draw.line([p, q], fill=color, width=width)


def ship(draw, color, width):
    # The ship, at the bottom of the rim (image y grows downward).
    pts = [(-0.5, 0.05), (-0.34, 0.34), (-0.18, 0.08), (0, 0.3), (0.18, 0.08), (0.34, 0.34), (0.5, 0.05), (0, -0.24)]
    lane = W * 0.27
    cy = C + W * 0.40 - lane * 0.42
    poly = [(C + x * lane, cy + y * lane) for x, y in pts]
    draw.line(poly + [poly[0]], fill=color, width=width, joint="curve")


def layer(draw_fn, color, width, blur):
    img = Image.new("RGB", (W, W), (0, 0, 0))
    draw_fn(ImageDraw.Draw(img), color, width)
    return img.filter(ImageFilter.GaussianBlur(blur)) if blur else img


def add(a, b):
    from PIL import ImageChops
    return ImageChops.add(a, b)


def main(path):
    background = Image.new("RGB", (W, W), (5, 3, 15))
    violet = (123, 92, 255)
    gold = (255, 210, 63)
    img = background
    for fn, color in ((strokes, violet), (ship, gold)):
        img = add(img, layer(fn, tuple(c // 2 for c in color), 44, 28))
        img = add(img, layer(fn, color, 10, 0))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png")
