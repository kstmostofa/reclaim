#!/usr/bin/env python3
"""Draws the PNG icons and the social-sharing image. Needs Pillow; run only when the artwork changes.

    python3 site/make_images.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
FONT = "/System/Library/Fonts/SFNS.ttf"


def gradient(size, start, end, diagonal=True):
    w, h = size
    image = Image.new("RGB", size)
    px = image.load()
    for y in range(h):
        for x in range(w):
            t = ((x / w) + (y / h)) / 2 if diagonal else x / w
            px[x, y] = tuple(int(start[i] + (end[i] - start[i]) * t) for i in range(3))
    return image


def mark(size):
    """The app mark: a rounded indigo tile with a disk-usage ring and a sparkle."""
    s = size * 4
    tile = gradient((s, s), (124, 122, 237), (79, 62, 200)).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 15 / 64), fill=255)
    tile.putalpha(mask)
    d = ImageDraw.Draw(tile)
    u = s / 64
    cx, cy, r, w = 30 * u, 34 * u, 16 * u, 7 * u
    box = (cx - r, cy - r, cx + r, cy + r)
    d.ellipse(box, outline=(255, 255, 255, 72), width=int(w))
    d.arc(box, start=-90, end=-90 + 288, fill=(255, 255, 255, 255), width=int(w))
    star = [(49, 9), (50.9, 14.1), (56, 16), (50.9, 17.9), (49, 23), (47.1, 17.9), (42, 16), (47.1, 14.1)]
    d.polygon([(x * u, y * u) for x, y in star], fill=(255, 255, 255, 255))
    return tile.resize((size, size), Image.LANCZOS)


def og_image():
    W, H = 1200, 630
    image = gradient((W, H), (18, 16, 48), (52, 30, 110)).convert("RGBA")
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((620, -120, 1400, 560), fill=(124, 122, 237, 120))
    image = Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(120)))

    shot = Image.open(ROOT / "static/screenshots/overview.png").convert("RGBA")
    shot = shot.resize((760, int(760 * shot.height / shot.width)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius=18, fill=255)
    shot.putalpha(mask)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((560, 150, 560 + shot.width, 150 + shot.height), radius=18, fill=(0, 0, 0, 150))
    image = Image.alpha_composite(image, shadow.filter(ImageFilter.GaussianBlur(30)))
    image.alpha_composite(shot, (540, 130))

    d = ImageDraw.Draw(image)
    image.alpha_composite(mark(88), (72, 92))
    title = ImageFont.truetype(FONT, 84)
    title.set_variation_by_name("Bold")
    body = ImageFont.truetype(FONT, 32)
    body.set_variation_by_name("Medium")
    d.text((72, 214), "Reclaim", font=title, fill=(255, 255, 255))
    lines = ["Free, open-source", "Mac storage cleaner", "for developers."]
    for i, line in enumerate(lines):
        d.text((74, 330 + i * 44), line, font=body, fill=(214, 212, 255))
    small = ImageFont.truetype(FONT, 22)
    d.text((74, 520), "node_modules · caches · Docker", font=small, fill=(170, 168, 230))
    image.convert("RGB").save(ASSETS / "og-image.png", optimize=True)


if __name__ == "__main__":
    mark(32).save(ASSETS / "favicon-32.png")
    mark(180).save(ASSETS / "apple-touch-icon.png")
    og_image()
    print("Wrote favicon-32.png, apple-touch-icon.png and og-image.png")
