#!/usr/bin/env python3
"""Draws the RideMA logo (our own design: a white map pin with a saffron dot on an emerald tile).

Reads the product name from lib/brand.dart (kAppName) so renaming stays a one-line change.
Writes SVG + PNG files to assets/brand/. Needs Pillow (pip install pillow).

Usage: python3 tool/make_logo.py
"""
import math
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'brand')
PRIMARY = '#0B6E4F'
ACCENT = '#F4A300'
INK = '#1D1D1F'

with open(os.path.join(ROOT, 'lib', 'brand.dart'), encoding='utf-8') as f:
    NAME = re.search(r"kAppName\s*=\s*'([^']+)'", f.read()).group(1)

# Pin geometry in a 100x100 box.
PIN_PATH = 'M50 84 C50 84 27 59 27 44 A23 23 0 1 1 73 44 C73 59 50 84 50 84 Z'


def mark_svg(size=100, tile=True):
    bg = f'<rect width="100" height="100" rx="22" fill="{PRIMARY}"/>' if tile else ''
    pin_fill = '#FFFFFF' if tile else PRIMARY
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{size}" height="{size}">'
            f'{bg}<path d="{PIN_PATH}" fill="{pin_fill}"/>'
            f'<circle cx="50" cy="44" r="10" fill="{ACCENT}"/>'
            f'<rect x="30" y="88" width="40" height="4" rx="2" fill="{ACCENT}"/></svg>\n')


def wordmark_svg():
    # Split the name so the last two letters (country code) get the brand colour.
    head, tail = (NAME[:-2], NAME[-2:]) if len(NAME) > 2 else (NAME, '')
    width = 120 + 34 * len(NAME)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 100" width="{width}" height="100">'
            f'<g><rect width="100" height="100" rx="22" fill="{PRIMARY}"/>'
            f'<path d="{PIN_PATH}" fill="#FFFFFF"/><circle cx="50" cy="44" r="10" fill="{ACCENT}"/>'
            f'<rect x="30" y="88" width="40" height="4" rx="2" fill="{ACCENT}"/></g>'
            f'<text x="116" y="68" font-family="Inter, Roboto, Arial, sans-serif" font-size="52" font-weight="800">'
            f'<tspan fill="{INK}">{head}</tspan><tspan fill="{PRIMARY}">{tail}</tspan></text></svg>\n')


def cubic(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t ** 2
        d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def pin_polygon():
    pts = cubic((50, 84), (50, 84), (27, 59), (27, 44))
    # Big arc from (27,44) over the top to (73,44): centre (50,44), r=23.
    for i in range(1, 61):
        ang = math.pi + math.pi * i / 60  # 180° -> 360°
        pts.append((50 + 23 * math.cos(ang), 44 + 23 * math.sin(ang)))
    pts += cubic((73, 44), (73, 59), (50, 84), (50, 84))[1:]
    return pts


def draw_mark(px, tile=True, padding=0.0):
    scale = 4  # supersample then downscale for smooth edges
    s = px * scale
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    inner = s * (1 - 2 * padding)
    off = s * padding
    k = inner / 100.0

    def tr(p):
        return (off + p[0] * k, off + p[1] * k)

    if tile:
        d.rounded_rectangle([off, off, off + inner, off + inner], radius=22 * k, fill=PRIMARY)
    d.polygon([tr(p) for p in pin_polygon()], fill='#FFFFFF' if tile else PRIMARY)
    cx, cy = tr((50, 44))
    d.ellipse([cx - 10 * k, cy - 10 * k, cx + 10 * k, cy + 10 * k], fill=ACCENT)
    x0, y0 = tr((30, 88))
    d.rounded_rectangle([x0, y0, x0 + 40 * k, y0 + 4 * k], radius=2 * k, fill=ACCENT)
    return img.resize((px, px), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'logo_mark.svg'), 'w', encoding='utf-8') as f:
        f.write(mark_svg())
    with open(os.path.join(OUT, 'logo_wordmark.svg'), 'w', encoding='utf-8') as f:
        f.write(wordmark_svg())
    draw_mark(512).save(os.path.join(OUT, 'logo_mark_512.png'))
    # Adaptive-icon foreground: keep the mark inside the 66% safe zone.
    draw_mark(1024, tile=False, padding=0.2).save(os.path.join(OUT, 'logo_foreground_1024.png'))
    print('Wrote', sorted(os.listdir(OUT)), 'for', NAME)


if __name__ == '__main__':
    main()
