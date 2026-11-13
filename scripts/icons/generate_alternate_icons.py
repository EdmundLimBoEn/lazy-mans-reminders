#!/usr/bin/env python3
"""Rebuild alternate icons and Settings thumbnails with Python 3 + Pillow.

Run from any directory: python3 scripts/icons/generate_alternate_icons.py
The shipped default is read only. Geometry follows its rounded page and rules;
all new drawing happens at 4x resolution before a Lanczos downsample.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios/App/Assets.xcassets"
SIZE = 1024
SUPERSAMPLE = 4
OPTIONS = ("Default", "Minimal", "Bold")


def icon_path(option: str) -> Path:
    name = "AppIcon" if option == "Default" else f"AppIcon-{option}"
    return ASSETS / f"{name}.appiconset" / "AppIcon.png"


def write_contents(directory: Path, images: list[dict]) -> None:
    (directory / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


def draw_icon(option: str, background: tuple, original_ink: tuple) -> Image.Image:
    scale = SUPERSAMPLE
    image = Image.new("RGB", (SIZE * scale, SIZE * scale), background)
    draw = ImageDraw.Draw(image)
    # Default: 500 x 640 page, 16 px border and 14 px rules. New page: 564 x 712.
    stroke = 30 if option == "Minimal" else 48
    rule = 30 if option == "Minimal" else 42
    ink = original_ink if option == "Minimal" else (74, 68, 60)
    draw.rounded_rectangle(
        tuple(v * scale for v in (230, 156, 794, 868)),
        radius=(stroke + 24) * scale,
        outline=ink,
        width=stroke * scale,
    )
    lines = (512,) if option == "Minimal" else (342, 456, 570, 684)
    left, right = (374, 650) if option == "Minimal" else (326, 698)
    for y in lines:
        draw.rectangle(
            (left * scale, (y - rule / 2) * scale,
             right * scale - 1, (y + rule / 2) * scale - 1),
            fill=ink,
        )
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main() -> None:
    with Image.open(icon_path("Default")) as source:
        default = source.convert("RGB")
    background = default.getpixel((0, 0))
    original_ink = default.getpixel((270, 500))
    for option in OPTIONS:
        icon = default if option == "Default" else draw_icon(option, background, original_ink)
        if option != "Default":
            path = icon_path(option)
            path.parent.mkdir(parents=True, exist_ok=True)
            icon.save(path)
            write_contents(path.parent, [{
                "filename": path.name, "idiom": "universal", "platform": "ios", "size": "1024x1024"
            }])
        # App icon assets aren't UIImage resources. Supply separate 48 pt images.
        directory = ASSETS / f"AppIconPreview-{option}.imageset"
        directory.mkdir(parents=True, exist_ok=True)
        images = []
        for scale in (1, 2, 3):
            name = f"preview@{scale}x.png"
            icon.resize((48 * scale, 48 * scale), Image.Resampling.LANCZOS).save(directory / name)
            images.append({"filename": name, "idiom": "universal", "scale": f"{scale}x"})
        write_contents(directory, images)


if __name__ == "__main__":
    main()
