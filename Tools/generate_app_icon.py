#!/usr/bin/env python3
import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_master_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. macOS squircle background geometry
    # Apple icon squircle is approx 824x824 inside 1024x1024 canvas (padded by 100px)
    pad = 100
    w = size - 2 * pad
    radius = int(w * 0.225) # ~185px corner radius

    # Background gradient
    bg_img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_img)

    # Create vertical gradient: #1E1B2E to #0F0E17
    for y in range(w):
        t = y / float(w)
        # Deep royal midnight indigo to obsidian
        r = int(24 * (1 - t) + 12 * t)
        g = int(22 * (1 - t) + 10 * t)
        b = int(42 * (1 - t) + 24 * t)
        bg_draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Mask with rounded rectangle
    mask = Image.new("L", (w, w), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (w, w)], radius=radius, fill=255)

    # Subtle inner border highlight
    border = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border)
    b_draw.rounded_rectangle([(1, 1), (w - 2, w - 2)], radius=radius, outline=(255, 255, 255, 38), width=2)

    # Composite rounded background
    rounded_bg = Image.composite(bg_img, Image.new("RGBA", (w, w), (0, 0, 0, 0)), mask)
    rounded_bg.paste(border, (0, 0), border)

    # Soft drop shadow for squircle
    shadow_pad = 20
    shadow = Image.new("RGBA", (w + shadow_pad * 2, w + shadow_pad * 2), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle([(shadow_pad, shadow_pad + 12), (w + shadow_pad, w + shadow_pad + 12)],
                             radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))

    # Paste shadow and squircle onto main canvas
    img.paste(shadow, (pad - shadow_pad, pad - shadow_pad), shadow)
    img.paste(rounded_bg, (pad, pad), rounded_bg)

    # 2. Draw Center Artwork: Glowing Acoustic Waveform Emblem
    cx = size // 2
    cy = size // 2

    # Draw subtle circular halo glow behind waveform
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(halo)
    halo_r = 220
    h_draw.ellipse([(cx - halo_r, cy - halo_r), (cx + halo_r, cy + halo_r)], fill=(0, 122, 255, 45))
    halo = halo.filter(ImageFilter.GaussianBlur(40))
    img.paste(halo, (0, 0), halo)

    # Audio Waveform bars
    # Heights modeled after a resonant voice utterance
    bar_heights = [45, 95, 160, 240, 310, 360, 310, 240, 160, 95, 45]
    num_bars = len(bar_heights)
    bar_width = 24
    bar_gap = 18
    total_w = num_bars * bar_width + (num_bars - 1) * bar_gap
    start_x = cx - (total_w // 2)

    wave_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)

    for i, h in enumerate(bar_heights):
        bx = start_x + i * (bar_width + bar_gap)
        by1 = cy - (h // 2)
        by2 = cy + (h // 2)
        br = bar_width // 2

        # Gradient along bar
        bar_img = Image.new("RGBA", (bar_width, h), (0, 0, 0, 0))
        b_canvas = ImageDraw.Draw(bar_img)
        for y in range(h):
            t = y / float(h)
            # Electric cyan (0, 210, 255) to vibrant purple (140, 80, 255)
            red = int(0 * (1 - t) + 160 * t)
            green = int(210 * (1 - t) + 90 * t)
            blue = int(255 * (1 - t) + 255 * t)
            b_canvas.line([(0, y), (bar_width, y)], fill=(red, green, blue, 255))

        bar_mask = Image.new("L", (bar_width, h), 0)
        bm_draw = ImageDraw.Draw(bar_mask)
        bm_draw.rounded_rectangle([(0, 0), (bar_width, h)], radius=br, fill=255)

        masked_bar = Image.composite(bar_img, Image.new("RGBA", (bar_width, h), (0, 0, 0, 0)), bar_mask)
        wave_layer.paste(masked_bar, (bx, by1), masked_bar)

    # Glow shadow for waveform
    wave_glow = wave_layer.copy().filter(ImageFilter.GaussianBlur(10))
    img.paste(wave_glow, (0, 0), wave_glow)
    img.paste(wave_layer, (0, 0), wave_layer)

    return img

def main():
    os.makedirs("Tools", exist_ok=True)
    os.makedirs("Resources", exist_ok=True)
    iconset_dir = "Tools/AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    print("▸ Generating 1024x1024 master AppIcon...")
    master = create_master_icon(1024)
    master.save("Resources/AppIcon-1024.png")

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for s, name in sizes:
        resized = master.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))

    print("▸ Compiling Resources/AppIcon.icns via iconutil...")
    icns_path = "Resources/AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"✓ Created {icns_path} ({os.path.getsize(icns_path)} bytes)")

if __name__ == "__main__":
    main()

