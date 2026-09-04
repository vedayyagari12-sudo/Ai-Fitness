"""Builds the 1024x500 Play Store feature graphic.

Composited from the app's own assets rather than drawn from scratch: the mark
is the real adaptive-icon foreground, the type is the real Outfit face the app
ships, and every colour is read from lib/theme/app_theme.dart's dark theme.

Run:  python tool/make_feature_graphic.py
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "store_assets/02_feature_graphic_1024x500.png"
W, H = 1024, 500

# Straight from app_theme.dart's darkTheme / accent tokens.
BG_DEEP = (0x0A, 0x0A, 0x0A)
BG_CARD = (0x14, 0x14, 0x14)
BRAND = (0x5A, 0xA3, 0xEC)  # kBrand, dark
TEXT_PRIMARY = (0xFF, 0xFF, 0xFF)
TEXT_SECONDARY = (0x8A, 0x8A, 0x8A)
ICON_BG = (0x0E, 0x12, 0x17)  # ic_launcher_background

OUTFIT = "test/store/fonts/Outfit.ttf"


def outfit(size, weight):
    """Outfit at a given weight. It is a variable font, so the weight axis is
    set explicitly — without this every string renders at the default 400 and
    the title reads limp next to the app's own headings."""
    f = ImageFont.truetype(OUTFIT, size)
    try:
        f.set_variation_by_axes([weight])
    except (OSError, AttributeError):
        pass  # Static build or no FreeType variation support; 400 is legible.
    return f


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return m


def build():
    img = Image.new("RGB", (W, H), BG_DEEP)

    # A wide, very soft brand wash behind the mark. The app puts a coloured
    # glow behind its rings and donut; this is the same idea at banner scale,
    # and it keeps the left half from reading as dead black.
    glow = Image.new("RGB", (W, H), BG_DEEP)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([40, 30, 660, 480], fill=(0x12, 0x2A, 0x42))
    glow = glow.filter(ImageFilter.GaussianBlur(110))
    img = Image.blend(img, glow, 0.85)

    # The real launcher mark, on its real tile colour, with the squircle Play
    # itself would apply.
    tile = 216
    fg = Image.open(
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
    ).convert("RGBA")
    icon = Image.alpha_composite(
        Image.new("RGBA", fg.size, ICON_BG + (255,)), fg
    ).resize((tile, tile), Image.LANCZOS)
    icon.putalpha(rounded_mask((tile, tile), 48))

    tx_gap = 60
    title_f = outfit(96, 700)
    tag_f = outfit(34, 500)

    title = "Physiqo AI"
    tagline = "AI physique scans & workouts"

    d = ImageDraw.Draw(img)
    t_box = d.textbbox((0, 0), title, font=title_f)
    g_box = d.textbbox((0, 0), tagline, font=tag_f)
    t_w, t_h = t_box[2] - t_box[0], t_box[3] - t_box[1]
    g_w, g_h = g_box[2] - g_box[0], g_box[3] - g_box[1]

    # Centre the mark + type as one group. Play crops this image towards the
    # centre on some surfaces, so anything pinned to an edge risks being cut.
    text_w = max(t_w, g_w)
    group_w = tile + tx_gap + text_w
    ix = (W - group_w) // 2
    iy = (H - tile) // 2

    img.paste(icon, (ix, iy), icon)
    # Hairline edge on the tile, matching the app's kGlassBorder treatment.
    d.rounded_rectangle(
        [ix, iy, ix + tile - 1, iy + tile - 1], 48, outline=(0x2A, 0x2A, 0x2A), width=2
    )

    tx = ix + tile + tx_gap
    gap = 20
    rule_h, rule_gap = 6, 26
    block_h = t_h + gap + g_h + rule_gap + rule_h
    top = (H - block_h) // 2

    d.text((tx, top - t_box[1]), title, font=title_f, fill=TEXT_PRIMARY)
    gy = top + t_h + gap
    d.text((tx, gy - g_box[1]), tagline, font=tag_f, fill=TEXT_SECONDARY)

    # The one piece of accent colour, so the banner carries the app's blue
    # without tinting the type.
    ry = gy + g_h + rule_gap
    d.rounded_rectangle([tx, ry, tx + 132, ry + rule_h], 3, fill=BRAND)

    img.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} {img.size}")


if __name__ == "__main__":
    build()
