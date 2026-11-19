#!/usr/bin/env python3
"""Render illustrative Home Screen and actual-pixel size comparisons with Pillow.

Run generate_alternate_icons.py first, then this script. Columns are always
Default / Minimal / Bold; size-chart rows are 180 / 120 / 87 / 58 / 40 px.
No product copy is introduced. Masks approximate iOS continuous rounded corners;
these are design comparisons, not simulator captures or exact system masks.
"""

import math

from PIL import Image, ImageDraw, ImageFilter

from generate_alternate_icons import OPTIONS, ROOT, icon_path

OUTPUT = ROOT / "docs/icons"


def mask(size: int) -> Image.Image:
    scale = 4
    side = size * scale
    result = Image.new("L", (side, side), 0)
    # A superellipse gives a smooth iOS-like squircle at every comparison size.
    points = []
    for step in range(720):
        angle = step * math.tau / 720
        x, y = math.cos(angle), math.sin(angle)
        points.append(((1 + math.copysign(abs(x) ** 0.5, x)) * (side - 1) / 2,
                       (1 + math.copysign(abs(y) ** 0.5, y)) * (side - 1) / 2))
    ImageDraw.Draw(result).polygon(points, fill=255)
    return result.resize((size, size), Image.Resampling.LANCZOS)


def place(canvas: Image.Image, icon: Image.Image, xy: tuple[int, int], size: int) -> None:
    canvas.paste(icon.resize((size, size), Image.Resampling.LANCZOS), xy, mask(size))


def wallpaper(dark: bool) -> Image.Image:
    width, height = 900, 900
    top, bottom = ((29, 40, 65), (53, 65, 68)) if dark else ((204, 219, 234), (215, 226, 219))
    canvas = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(canvas)
    for y in range(height):
        t = y / (height - 1)
        color = tuple(round(a * (1 - t) + b * t) for a, b in zip(top, bottom))
        draw.line((0, y, width, y), fill=color)
    haze = Image.new("RGBA", canvas.size)
    draw = ImageDraw.Draw(haze)
    draw.ellipse((-190, 140, 720, 1050), fill=(103, 100, 151, 90 if dark else 45))
    draw.ellipse((470, -300, 1150, 600), fill=(111, 171, 159, 65 if dark else 85))
    return Image.alpha_composite(canvas.convert("RGBA"), haze.filter(ImageFilter.GaussianBlur(95))).convert("RGB")


def placeholder(index: int, dark: bool) -> Image.Image:
    base, ink = ((88, 94, 104), (153, 158, 167)) if dark else ((179, 185, 192), (224, 227, 230))
    icon = Image.new("RGB", (180, 180), base)
    draw = ImageDraw.Draw(icon)
    if index % 3 == 0:
        draw.ellipse((56, 56, 124, 124), outline=ink, width=10)
    elif index % 3 == 1:
        draw.rounded_rectangle((53, 53, 127, 127), radius=15, outline=ink, width=10)
    else:
        for y in (63, 85, 107):
            draw.rounded_rectangle((55, y, 125, y + 9), radius=4, fill=ink)
    return icon


def home(icons: list[Image.Image], dark: bool) -> Image.Image:
    canvas = wallpaper(dark)
    columns = (100, 360, 620)
    for row, y in enumerate((92, 360, 628)):
        for column, x in enumerate(columns):
            icon = icons[column] if row == 1 else placeholder(column + row, dark)
            # Small neutral shadows and label-shaped bars provide context without copy.
            shadow = Image.new("RGBA", canvas.size)
            shadow.paste((0, 0, 0, 35), (x, y + 5), mask(180))
            canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(7))).convert("RGB")
            place(canvas, icon, (x, y), 180)
            draw = ImageDraw.Draw(canvas)
            draw.rounded_rectangle((x + 42, y + 198, x + 138, y + 205), radius=3,
                                   fill=(153, 161, 177) if dark else (128, 140, 154))
    return canvas


def sizes(icons: list[Image.Image]) -> Image.Image:
    canvas = Image.new("RGB", (900, 720), (221, 226, 230))
    y = 36
    for row, size in enumerate((180, 120, 87, 58, 40)):
        ImageDraw.Draw(canvas).rectangle((0, y - 12, 899, y + size + 12),
                                        fill=(232, 235, 238) if row % 2 == 0 else (211, 218, 223))
        for center, icon in zip((190, 450, 710), icons):
            place(canvas, icon, (center - size // 2, y), size)
        y += size + 36
    return canvas


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    icons = []
    for option in OPTIONS:
        with Image.open(icon_path(option)) as source:
            icons.append(source.convert("RGB"))
    home(icons, dark=False).save(OUTPUT / "preview-home-light.png")
    home(icons, dark=True).save(OUTPUT / "preview-home-dark.png")
    sizes(icons).save(OUTPUT / "preview-sizes.png")


if __name__ == "__main__":
    main()
