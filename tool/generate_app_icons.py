#!/usr/bin/env python3
"""Generates every launcher icon in the repo from one description, so the mark
can be edited here instead of in a binary someone has to open a design tool for.

    python3 tool/generate_app_icons.py

Needs Pillow and the Material Icons font that ships with the Flutter SDK — the
glyph is the same `Icons.call` the app draws in its own UI, so the launcher icon
and the login screen cannot drift apart.

Writes: assets/icon/, android mipmaps (legacy + adaptive foreground), the iOS
appiconset, and web/icons + web/favicon.png.
"""

import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FONT = os.path.expanduser(
    "~/fvm/versions/3.38.1/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
)
CALL_GLYPH = "\ue126"   # Icons.call
CHECK_GLYPH = "\ue156"  # Icons.check

# AppColors, kept in sync by hand — see lib/ui/common/app_colors.dart.
ORANGE_LIGHT = (245, 119, 61)   # top-left of the background gradient
ORANGE_DARK = (222, 84, 28)     # bottom-right
GREEN = (61, 163, 93)           # AppColors.greenColor, the "verified" badge
CREAM = (250, 246, 241)         # AppColors.backgroundColor, the badge's ring
WHITE = (255, 255, 255)

SS = 4  # supersample factor; everything is drawn at 4x and shrunk for edges


def _gradient(size):
    """Diagonal two-stop gradient, built small and scaled up so it stays smooth."""
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            px[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(ORANGE_LIGHT, ORANGE_DARK)
            )
    return small.resize((size, size), Image.BICUBIC)


def _glyph(size, glyph, color):
    """One Material glyph rendered tight to its ink, as an RGBA image."""
    font = ImageFont.truetype(FONT, size)
    box = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    ImageDraw.Draw(box).text((size // 2, size // 2), glyph, font=font, fill=color)
    return box.crop(box.getbbox())


def _mark(width):
    """The logo mark on transparent: handset plus a check badge on its corner.

    `width` is the full width of the group, badge included, so callers can size
    the mark against a safe zone without measuring it themselves.
    """
    canvas = Image.new("RGBA", (width, width), (0, 0, 0, 0))

    handset = _glyph(round(width * 0.92), CALL_GLYPH, WHITE)
    scale = round(width * 0.86) / max(handset.size)
    handset = handset.resize(
        (round(handset.width * scale), round(handset.height * scale)), Image.LANCZOS
    )
    canvas.alpha_composite(
        handset, ((width - handset.width) // 2, (width - handset.height) // 2)
    )

    # Badge, bottom-right, ringed in the app's cream so it reads against orange.
    badge = round(width * 0.42)
    ring = round(width * 0.045)
    cx = width - badge // 2
    cy = width - badge // 2
    draw = ImageDraw.Draw(canvas)
    draw.ellipse(
        [cx - badge // 2, cy - badge // 2, cx + badge // 2, cy + badge // 2],
        fill=CREAM + (255,),
    )
    inner = badge - ring * 2
    draw.ellipse(
        [cx - inner // 2, cy - inner // 2, cx + inner // 2, cy + inner // 2],
        fill=GREEN + (255,),
    )

    check = _glyph(round(inner * 1.1), CHECK_GLYPH, WHITE)
    scale = round(inner * 0.62) / max(check.size)
    check = check.resize(
        (round(check.width * scale), round(check.height * scale)), Image.LANCZOS
    )
    canvas.alpha_composite(check, (cx - check.width // 2, cy - check.height // 2))
    return canvas


def full_bleed(size, mark_fraction=0.62, rounded=False):
    """Gradient square with the mark centred. `rounded` cuts the corners out."""
    big = size * SS
    img = _gradient(big).convert("RGBA")

    mark = _mark(round(big * mark_fraction))
    # Nudged up and left by half the badge overhang so the handset — not the
    # group's bounding box — is what looks centred.
    off = (big - mark.width) // 2
    img.alpha_composite(mark, (off - round(big * 0.015), off - round(big * 0.02)))

    if rounded:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=round(big * 0.22), fill=255
        )
        img.putalpha(mask)

    return img.resize((size, size), Image.LANCZOS)


def foreground(size, mark_fraction=0.46):
    """Adaptive-icon foreground: mark only, inside the 66% safe zone."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    mark = _mark(round(big * mark_fraction))
    off = (big - mark.width) // 2
    img.alpha_composite(mark, (off - round(big * 0.012), off - round(big * 0.016)))
    return img.resize((size, size), Image.LANCZOS)


def notification(size):
    """Status-bar icon: the handset alone, white on transparent.

    Android throws the colour away and keeps only the alpha, so the badge would
    come out as a filled disc — it is left off, and there is no gradient to
    speak of either.
    """
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    handset = _glyph(big, CALL_GLYPH, WHITE)
    scale = round(big * 0.88) / max(handset.size)
    handset = handset.resize(
        (round(handset.width * scale), round(handset.height * scale)), Image.LANCZOS
    )
    img.alpha_composite(
        handset, ((big - handset.width) // 2, (big - handset.height) // 2)
    )
    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts, opaque=False):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        # iOS rejects an app icon with an alpha channel.
        flat = Image.new("RGB", img.size, ORANGE_DARK)
        flat.paste(img, mask=img.split()[3])
        img = flat
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    master = full_bleed(1024)
    save(master, "assets", "icon", "app_icon.png", opaque=True)
    save(foreground(1024), "assets", "icon", "app_icon_foreground.png")

    # Android legacy: rounded square, one per density (48dp).
    for density, px in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)
    ]:
        save(
            full_bleed(px, rounded=True),
            "android", "app", "src", "main", "res", f"mipmap-{density}", "ic_launcher.png",
        )
    # Android adaptive foreground: 108dp, so 2.25x the legacy pixel size.
    for density, px in [
        ("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)
    ]:
        save(
            foreground(px),
            "android", "app", "src", "main", "res", f"mipmap-{density}",
            "ic_launcher_foreground.png",
        )

    # Android status bar: 24dp, in drawable-* rather than mipmap-* because it is
    # density-specific artwork, not a launcher icon.
    for density, px in [
        ("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)
    ]:
        save(
            notification(px),
            "android", "app", "src", "main", "res", f"drawable-{density}",
            "ic_notification.png",
        )

    # iOS: every size Contents.json asks for, resized off the 1024 master.
    appicon = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    contents = json.load(open(os.path.join(appicon, "Contents.json")))
    for entry in contents["images"]:
        pt = float(entry["size"].split("x")[0])
        px = round(pt * float(entry["scale"].rstrip("x")))
        save(
            master.resize((px, px), Image.LANCZOS),
            "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset", entry["filename"],
            opaque=True,
        )

    # Web: plain icons full-bleed, maskable ones with the mark pulled in so a
    # circular mask cannot clip the badge.
    for px in (192, 512):
        save(master.resize((px, px), Image.LANCZOS), "web", "icons", f"Icon-{px}.png")
        save(full_bleed(px, mark_fraction=0.46), "web", "icons", f"Icon-maskable-{px}.png")
    save(full_bleed(32, rounded=True), "web", "favicon.png")


if __name__ == "__main__":
    main()
