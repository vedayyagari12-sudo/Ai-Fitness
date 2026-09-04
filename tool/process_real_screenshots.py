"""Turns the real device captures in store_assets/raw/ into Play-ready shots.

These are genuine screenshots of the running app, so they are the most honest
thing to put on the listing. Three things stand between them and Play:

  1. Several carry the red Flutter DEBUG ribbon in the top-right corner. That
     cannot ship — it advertises a debug build.
  2. Some include the phone status bar, and one is a screenshot shared through
     a messaging app, so it carries that app's chrome top and bottom.
  3. They are 9:19.5 or odd mirror-window sizes; Play wants each phone shot
     between 16:9 and 9:16, and a consistent set looks far better.

Every fill here is edge replication from the image's own pixels, never an
invented colour: the app paints a vertical gradient (kPageGradient), which is
horizontally uniform, so extending a row sideways is seamless and extending
the top/bottom row vertically continues the gradient's own end colour.

Run:  python tool/process_real_screenshots.py
"""

from PIL import Image

RAW = "store_assets/raw"
TARGET = (1080, 1920)  # 9:16, the tallest Play accepts for a phone shot


def trim_borders(im):
    """Drop the black window-border strips the mirror capture leaves.

    Up to 15px down one side on these files. Left in, edge replication copies
    that black column outward and the finished shot gets a hard black band
    beside the app instead of the page gradient.
    """
    w, h = im.size
    px = im.load()

    def col_dark(x):
        ys = range(0, h, 7)
        return sum(sum(px[x, y]) for y in ys) / (len(list(ys)) * 3) < 6

    def row_dark(y):
        xs = range(0, w, 7)
        return sum(sum(px[x, y]) for x in xs) / (len(list(xs)) * 3) < 6

    left = 0
    while left < w // 4 and col_dark(left):
        left += 1
    right = w - 1
    while right > 3 * w // 4 and col_dark(right):
        right -= 1
    top = 0
    while top < h // 4 and row_dark(top):
        top += 1
    bottom = h - 1
    while bottom > 3 * h // 4 and row_dark(bottom):
        bottom -= 1
    return im.crop((left, top, right + 1, bottom + 1))


def clear_debug_ribbon(im):
    """Crop off the top strip carrying the red Flutter DEBUG ribbon.

    Cropping, not painting over. An earlier pass filled the top-right corner
    with background and destroyed real content with it — the BODY screen has
    an "AUG 31" date chip in exactly that corner. The ribbon only ever occupies
    the first few rows, so trimming them costs nothing and cannot erase a
    control.

    The row extent is measured per image rather than assumed: it runs 9-12px
    on the mirror captures and ~40px on the one that also shows the phone
    status bar. Detection is deliberately confined to the far corner and to
    strongly saturated red, because a wider test matched the warm tones in the
    food photo and would have cropped the whole header away.
    """
    w, h = im.size
    px = im.load()
    rows = [
        y
        for y in range(int(h * 0.10))
        for x in range(int(w * 0.86), w)
        if px[x, y][0] > 110
        and px[x, y][0] > px[x, y][1] * 2.2
        and px[x, y][0] > px[x, y][2] * 2.2
    ]
    return im.crop((0, max(rows) + 9, w, h)) if rows else im


def replicate_pad(im, target):
    """Fit inside target, then pad by repeating the edge pixels.

    Scaling to fit rather than cropping to fill: these screens are already
    composed, and cropping would slice a card. Padding by replication keeps
    the app's own gradient running to the frame edge instead of dropping a
    flat band beside it.
    """
    tw, th = target
    w, h = im.size
    scale = min(tw / w, th / h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    im = im.resize((nw, nh), Image.LANCZOS)

    out = Image.new("RGB", target)
    ox, oy = (tw - nw) // 2, (th - nh) // 2
    out.paste(im, (ox, oy))

    px, sp = out.load(), im.load()
    for y in range(nh):
        left, right = sp[0, y], sp[nw - 1, y]
        for x in range(ox):
            px[x, oy + y] = left
        for x in range(ox + nw, tw):
            px[x, oy + y] = right
    for y in range(oy):
        for x in range(tw):
            px[x, y] = px[x, oy]
    for y in range(oy + nh, th):
        for x in range(tw):
            px[x, y] = px[x, oy + nh - 1]
    return out


def process(src, dst, *, crop=None, ribbon=True):
    im = Image.open(f"{RAW}/{src}").convert("RGB")
    if crop:
        im = im.crop(crop)
    im = trim_borders(im)
    if ribbon:
        im = clear_debug_ribbon(im)
    out = replicate_pad(im, TARGET)
    out.save(f"store_assets/{dst}", "PNG", optimize=True)
    print(f"{dst:40} <- {src} {Image.open(f'{RAW}/{src}').size} -> {out.size}")


if __name__ == "__main__":
    # Mirror-window captures. raw_body also carries the phone status bar, so
    # its top strip goes; the others start at the app's own header.
    process("raw_scan_food.png", "05_screenshot_food_scan.png")
    process("raw_scan_physique.png", "06_screenshot_physique_scan.png", ribbon=False)
    process("raw_body.png", "07_screenshot_body.png")
    process("raw_train.png", "08_screenshot_workout.png")

    # A native 1080x2340 phone screenshot, shared through a messaging app:
    # its chrome is cropped off top and bottom, leaving the app's own page.
    #
    # Kept OUT of the numbered set, and named accordingly. It is by far the
    # sharpest capture here, but every row shows its scan date truncated to
    # "A..." — the exact bug fixed in commit 0c9d2d1, which this build
    # predates. Shipping it would advertise a defect that no longer exists.
    # Re-capture this screen on a current build and it becomes the best shot
    # in the set.
    process(
        "raw_scan_history_light.jpg",
        "optional_scan_history_light.png",
        crop=(0, 470, 1080, 2055),
        ribbon=False,
    )
