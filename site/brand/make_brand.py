#!/usr/bin/env python3
"""Draws every Reclaim icon from one geometry: the app icon set, the menu-bar template icon, the website
logo and favicons, and the social-sharing image. Needs Pillow; run only when the artwork changes.

    python3 site/brand/make_brand.py

The mark is a pie chart with its top-right quarter pulled out: disk space, with the part you reclaim.
Flat colours only.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SITE = ROOT / "site"
ICONSET = ROOT / "App/Assets.xcassets/AppIcon.appiconset"
MENUBAR = ROOT / "App/Assets.xcassets/MenuBarIcon.imageset"

TILE = (23, 23, 28)        # near-black
WHITE = (255, 255, 255)
INDIGO = (88, 86, 214)     # #5856D6, the app's accent

# Geometry on a 1024 canvas, following the macOS icon grid: an 824 tile with 185 corner radius.
R = 250                    # pie radius
GAP = 46                   # how far the slice is pulled out, along its bisector
SLICE = (-90, 0)           # top-right quarter, in PIL's degrees (0 = 3 o'clock, clockwise)
OFFSET = GAP / 2 ** 0.5    # x and y shift of the slice


def mark_box(scale=1.0):
    """Pie centre so that the pie and its pulled-out slice are centred together on the canvas."""
    width = 2 * R + OFFSET
    return 512 - width / 2 + R, 512 + width / 2 - R


def draw_mark(d, s, cx, cy, pie, slice_, r=R, offset=OFFSET):
    d.pieslice((s * (cx - r), s * (cy - r), s * (cx + r), s * (cy + r)), 0, 270, fill=pie)
    ox, oy = cx + offset, cy - offset
    d.pieslice((s * (ox - r), s * (oy - r), s * (ox + r), s * (oy + r)), *SLICE, fill=slice_)


def app_icon(size, tile=True):
    s = 4 * size / 1024
    image = Image.new("RGBA", (4 * size, 4 * size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    if tile:
        d.rounded_rectangle((100 * s, 100 * s, 924 * s, 924 * s), radius=185 * s, fill=TILE)
    cx, cy = mark_box()
    draw_mark(d, s, cx, cy, WHITE, INDIGO)
    return image.resize((size, size), Image.LANCZOS)


def full_bleed(size):
    """For the Apple touch icon, which iOS and browsers round themselves."""
    s = 4 * size / 1024
    image = Image.new("RGBA", (4 * size, 4 * size), TILE)
    d = ImageDraw.Draw(image)
    cx, cy = mark_box()
    # A little larger, since there is no tile margin.
    scale = 1.18
    draw_mark(d, s, 512 + (cx - 512) * scale, 512 + (cy - 512) * scale, WHITE, INDIGO, R * scale, OFFSET * scale)
    return image.resize((size, size), Image.LANCZOS)


def menu_bar(points):
    """Black on transparent; macOS tints template images for light and dark menu bars."""
    px = points * 8
    image = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    s = px / 1024
    r, off = 400, 64
    cx, cy = 512 - off / 2, 512 + off / 2
    draw_mark(d, s, cx, cy, (0, 0, 0, 255), (0, 0, 0, 255), r, off)
    return image.resize((points * 2, points * 2), Image.LANCZOS), image.resize((points, points), Image.LANCZOS)


def svg_mark(pie="currentColor", slice_="#5856D6", tile=None):
    """The mark as SVG. Without a tile the pie takes the text colour, so it works on light and dark pages."""
    cx, cy = mark_box()
    ox, oy = cx + OFFSET, cy - OFFSET
    pie_path = f"M{cx:.1f} {cy:.1f}H{cx + R:.1f}A{R} {R} 0 1 1 {cx:.1f} {cy - R:.1f}Z"
    slice_path = f"M{ox:.1f} {oy:.1f}V{oy - R:.1f}A{R} {R} 0 0 1 {ox + R:.1f} {oy:.1f}Z"
    view = "0 0 1024 1024" if tile else "232 232 560 560"
    back = f'<rect x="100" y="100" width="824" height="824" rx="185" fill="{tile}"/>' if tile else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}">{back}'
            f'<path class="pie" d="{pie_path}" fill="{pie}"/><path class="slice" d="{slice_path}" fill="{slice_}"/></svg>\n')


def og_image():
    W, H = 1200, 630
    image = Image.new("RGB", (W, H), (13, 13, 18))
    d = ImageDraw.Draw(image)
    shot = Image.open(SITE / "static/screenshots/overview.png").convert("RGB")
    shot = shot.resize((700, int(700 * shot.height / shot.width)), Image.LANCZOS)
    frame = Image.new("RGB", (shot.width + 2, shot.height + 2), (52, 52, 64))
    frame.paste(shot, (1, 1))
    mask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), radius=16, fill=255)
    image.paste(frame, (560, 120), mask)
    image.paste(app_icon(132), (60, 70), app_icon(132))
    font = "/System/Library/Fonts/SFNS.ttf"
    title = ImageFont.truetype(font, 80)
    title.set_variation_by_name("Bold")
    body = ImageFont.truetype(font, 32)
    body.set_variation_by_name("Medium")
    d.text((76, 236), "Reclaim", font=title, fill=WHITE)
    for i, line in enumerate(["Free, open-source", "Mac storage cleaner", "for developers."]):
        d.text((78, 344 + i * 44), line, font=body, fill=(196, 196, 214))
    d.rectangle((78, 520, 78 + 64, 526), fill=INDIGO)
    image.save(SITE / "assets/og-image.png", optimize=True)


def main():
    # macOS app icon set.
    images = []
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = points * scale
            name = f"icon_{points}x{points}{'@2x' if scale == 2 else ''}.png"
            app_icon(px).save(ICONSET / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"})
    (ICONSET / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))

    # Menu-bar template icon, 18 pt.
    MENUBAR.mkdir(exist_ok=True)
    big, small = menu_bar(18)
    small.save(MENUBAR / "menubar.png")
    big.save(MENUBAR / "menubar@2x.png")
    (MENUBAR / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "menubar.png", "idiom": "universal", "scale": "1x"},
                   {"filename": "menubar@2x.png", "idiom": "universal", "scale": "2x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }, indent=2))

    # Website.
    assets = SITE / "assets"
    (assets / "logo.svg").write_text(svg_mark())
    (assets / "favicon.svg").write_text(svg_mark(pie="#ffffff", tile="#17171C"))
    (SITE / "brand/icon.svg").write_text(svg_mark(pie="#ffffff", tile="#17171C"))
    app_icon(32).save(assets / "favicon-32.png")
    full_bleed(180).convert("RGB").save(assets / "apple-touch-icon.png")
    app_icon(512).save(assets / "app-icon-512.png")
    og_image()
    print("Wrote the app icon set, menu-bar icon, logo, favicons and social image")


if __name__ == "__main__":
    main()
