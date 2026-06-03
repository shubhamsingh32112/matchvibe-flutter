"""Process nav bar PNG assets: remove background, crop, resize."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "lib" / "assets" / "nav"


def remove_dark_background(img: Image.Image) -> Image.Image:
    """Remove dark navy/matte backgrounds (VIP asset)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = (r + g + b) / 3
            mx = max(r, g, b)
            spread = mx - min(r, g, b)
            if lum < 32 and mx < 50:
                px[x, y] = (r, g, b, 0)
            elif lum < 55 and spread < 40:
                t = max(0.0, min(1.0, (lum - 20) / 35))
                px[x, y] = (r, g, b, int(255 * t))
    return img


def remove_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            spread = max(r, g, b) - min(r, g, b)
            avg = (r + g + b) / 3
            if spread < 50 and avg > 160:
                if avg > 198:
                    px[x, y] = (r, g, b, 0)
                else:
                    t = (avg - 160) / 38
                    px[x, y] = (r, g, b, int(255 * t))
    return img


def crop_to_content(img: Image.Image, padding: int = 8) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        return img
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img.width, right + padding)
    bottom = min(img.height, bottom + padding)
    return img.crop((left, top, right, bottom))


def fit_square(img: Image.Image, size: int = 128) -> Image.Image:
    img = crop_to_content(img)
    w, h = img.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2), img)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def process_file(src: Path, dst: Path) -> None:
    img = remove_background(Image.open(src))
    img = fit_square(img)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")
    print(f"Wrote {dst} ({img.size})")


def build_profile_icon(dst: Path, size: int = 128) -> None:
    """Gradient person silhouette matching nav asset style."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    cx, cy = size // 2, size // 2
    head_r = int(size * 0.17)
    draw.ellipse(
        (cx - head_r, cy - head_r - size * 0.08, cx + head_r, cy + head_r - size * 0.08),
        fill=255,
    )
    body_w = int(size * 0.52)
    body_h = int(size * 0.28)
    draw.rounded_rectangle(
        (
            cx - body_w // 2,
            cy + int(size * 0.02),
            cx + body_w // 2,
            cy + int(size * 0.02) + body_h,
        ),
        radius=body_w // 2,
        fill=255,
    )

    grad = Image.new("RGBA", (size, size))
    gpx = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            r = int(94 + t * (229 - 94))
            g = int(53 + t * (57 - 53))
            b = int(176 + t * (53 - 176))
            gpx[x, y] = (r, g, b, 255)

    img = Image.composite(grad, img, mask)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, "PNG")
    print(f"Wrote {dst} (generated profile)")


def main() -> None:
    assets = Path(
        r"C:\Users\user\.cursor\projects\d-zztherapy\assets"
    )
    sources = {
        "nav_home_icon.png": assets
        / "c__Users_user_AppData_Roaming_Cursor_User_workspaceStorage_4dd409d98c06724ebbf4a5a6432fe0c4_images_WhatsApp_Image_2026-06-03_at_5.46.20_AM-0c6696c2-09dd-4ae2-9fe7-a2c359a81836.png",
        "nav_moments_icon.png": assets
        / "c__Users_user_AppData_Roaming_Cursor_User_workspaceStorage_4dd409d98c06724ebbf4a5a6432fe0c4_images_image-6d933755-097c-4727-ab6a-5b4fa0174137.png",
        "nav_chats_icon.png": assets
        / "c__Users_user_AppData_Roaming_Cursor_User_workspaceStorage_4dd409d98c06724ebbf4a5a6432fe0c4_images_image-5fa738a8-aac5-40ad-a460-f50a7db35861.png",
        "nav_vip_icon.png": assets
        / "c__Users_user_AppData_Roaming_Cursor_User_workspaceStorage_4dd409d98c06724ebbf4a5a6432fe0c4_images_WhatsApp_Image_2026-06-03_at_7.45.59_AM-cbf20a3e-88a5-4b53-af18-20e1bbeb651f.png",
    }

    for name, src in sources.items():
        if not src.exists():
            print(f"Skip missing: {src}", file=sys.stderr)
            continue
        if name == "nav_vip_icon.png":
            img = remove_background(Image.open(src))
            img = fit_square(img, size=160)
            dst = OUT_DIR / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            img.save(dst, "PNG")
            print(f"Wrote {dst} ({img.size})")
        else:
            process_file(src, OUT_DIR / name)

    build_profile_icon(OUT_DIR / "nav_profile_icon.png")


if __name__ == "__main__":
    main()
