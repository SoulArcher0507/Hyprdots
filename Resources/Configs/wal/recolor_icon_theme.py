#!/usr/bin/env python3
import json
import os
import pathlib
import re
import shutil
import colorsys
from functools import lru_cache


hex_re = re.compile(r'(?i)#(?:[0-9a-f]{6}|[0-9a-f]{3})')
rgb_func_re = re.compile(r'(?i)rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)')
folder_name_re = re.compile(
    r'^(folder|folder-|inode-directory|user-(desktop|home|trash)|go-home|network-workgroup|network-server|drive-(harddisk|removable|optical)|start-here)'
)
small_places_sizes = {'16', '18', '20', '22', '24', '32'}
alias_groups = {
    'downloads': ['folder-download', 'folder-downloads', 'folder-download-blue', 'folder'],
    'documents': ['folder-documents', 'folder-document', 'folder-txt', 'folder'],
    'music': ['folder-music', 'folder-sound', 'folder'],
    'pictures': ['folder-pictures', 'folder-images', 'folder'],
    'videos': ['folder-videos', 'folder-video', 'folder'],
    'desktop': ['folder-desktop', 'user-desktop', 'folder'],
    'public': ['folder-publicshare', 'folder-public', 'folder-network', 'folder'],
    'templates': ['folder-templates', 'folder-txt', 'folder'],
    'home': ['folder-home', 'go-home', 'user-home', 'folder'],
    'trash': ['user-trash', 'trash-empty', 'trash-full', 'user-trash-full', 'folder'],
}

root = pathlib.Path(os.environ['DYNAMIC_THEME_DIR'])
palette_source = pathlib.Path(os.environ['DYNAMIC_PALETTE_SOURCE'])
raw = json.loads(palette_source.read_text(encoding='utf-8'))
colors = raw.get('colors', {})
qs = raw.get('quickshell', {})
palette = [colors[f'color{i}'] for i in range(16) if f'color{i}' in colors]
if len(palette) < 8:
    raise SystemExit('Palette troppo corta')

accent_hex = qs.get('accent') or colors.get('color4') or palette[4]
accent2_hex = qs.get('accent2') or colors.get('color6') or palette[6]
bg_hex = qs.get('bg') or raw.get('special', {}).get('background') or colors.get('color0') or palette[0]
fg_hex = qs.get('fg') or raw.get('special', {}).get('foreground') or colors.get('color7') or palette[7]
muted_hex = qs.get('muted') or colors.get('color8') or palette[8]


def expand_hex(h: str) -> str:
    h = h.lower()
    if len(h) == 4:
        return '#' + ''.join(ch * 2 for ch in h[1:])
    return h


@lru_cache(maxsize=None)
def hex_to_rgb(h: str):
    h = expand_hex(h).lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))



def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % tuple(max(0, min(255, int(round(v)))) for v in rgb)


@lru_cache(maxsize=None)
def rgb_to_hls(rgb):
    r, g, b = [x / 255.0 for x in rgb]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h, l, s



def hls_to_rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return (r * 255, g * 255, b * 255)



def perceptual_distance(a, b):
    ah, al, asat = rgb_to_hls(a)
    bh, bl, bsat = rgb_to_hls(b)
    hue = min(abs(ah - bh), 1 - abs(ah - bh))
    return hue * 3.2 + abs(al - bl) * 0.7 + abs(asat - bsat) * 0.9



def mix_rgb(a, b, t):
    return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))



def is_neutral(rgb):
    _, l, s = rgb_to_hls(rgb)
    return s < 0.12 or l < 0.045 or l > 0.965



def icon_kind(path: pathlib.Path) -> str:
    stem = path.stem.lower()
    parts = {p.lower() for p in path.parts}
    if 'places' in parts or folder_name_re.match(stem):
        return 'folder'
    if 'mimetypes' in parts or stem.startswith('application-') or stem.startswith('text-') or stem.startswith('video-') or stem.startswith('audio-'):
        return 'mime'
    return 'generic'


accent = hex_to_rgb(accent_hex)
accent2 = hex_to_rgb(accent2_hex)
bg = hex_to_rgb(bg_hex)
fg = hex_to_rgb(fg_hex)
muted = hex_to_rgb(muted_hex)
targets = tuple(hex_to_rgb(c) for c in palette)

folder_shadow = mix_rgb(accent, bg, 0.42)
folder_mid = mix_rgb(accent, accent2, 0.28)
folder_light = mix_rgb(accent2, fg, 0.18)
folder_outline = mix_rgb(accent, bg, 0.55)


@lru_cache(maxsize=None)
def remap_rgb_folder(rgb):
    if is_neutral(rgb):
        return rgb
    _, l, s = rgb_to_hls(rgb)
    if l >= 0.82:
        base = folder_light
        target_l = 0.78
    elif l >= 0.64:
        base = folder_light
        target_l = 0.68
    elif l >= 0.46:
        base = folder_mid
        target_l = 0.54
    elif l >= 0.28:
        base = accent
        target_l = 0.41
    else:
        base = folder_shadow
        target_l = 0.28
    bh, bl, bs = rgb_to_hls(base)
    nl = max(0.14, min(0.86, target_l * 0.72 + l * 0.28))
    ns = max(0.35, min(0.98, s * 0.20 + bs * 0.80))
    return hls_to_rgb(bh, nl, ns)


@lru_cache(maxsize=None)
def remap_rgb_generic(rgb):
    h, l, s = rgb_to_hls(rgb)
    if is_neutral(rgb):
        return rgb
    base = min(targets, key=lambda t: perceptual_distance(rgb, t))
    bh, bl, bs = rgb_to_hls(base)
    nl = max(0.10, min(0.90, l * 0.52 + bl * 0.48))
    ns = max(0.26, min(0.98, s * 0.22 + bs * 0.78))
    return hls_to_rgb(bh, nl, ns)


@lru_cache(maxsize=None)
def remap_rgb(rgb, kind):
    if kind == 'folder':
        return remap_rgb_folder(rgb)
    return remap_rgb_generic(rgb)


svg_changed = 0
for svg in root.rglob('*.svg'):
    if svg.is_symlink():
        continue
    try:
        text = svg.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        text = svg.read_text(encoding='latin-1')

    if '#' not in text and 'rgb(' not in text.lower():
        continue

    kind = icon_kind(svg)

    def repl_hex(match):
        src_raw = match.group(0)
        src = expand_hex(src_raw)
        rgb = hex_to_rgb(src)
        dst = rgb_to_hex(remap_rgb(rgb, kind))
        return dst

    def repl_rgb(match):
        rgb = tuple(max(0, min(255, int(match.group(i)))) for i in (1, 2, 3))
        nr, ng, nb = [int(round(v)) for v in remap_rgb(rgb, kind)]
        return f'rgb({nr},{ng},{nb})'

    new_text = hex_re.sub(repl_hex, text)
    new_text = rgb_func_re.sub(repl_rgb, new_text)

    if kind == 'folder':
        outline_hex = rgb_to_hex(folder_outline)
        new_text = re.sub(r'(?i)(stroke(?:-color)?=")#?[0-9a-f]{6}(\")', lambda m: f'{m.group(1)}{outline_hex}{m.group(2)}', new_text)

    if new_text != text:
        svg.write_text(new_text, encoding='utf-8')
        svg_changed += 1



def _place_rank(path: pathlib.Path):
    size = path.parent.parent.name if len(path.parents) >= 2 else ''
    parts = {part.lower() for part in path.parts}
    stem = path.stem.lower()
    is_symbolic = 'symbolic' in parts or stem.endswith('-symbolic')
    if size == 'scalable':
        size_score = 0
    elif size.isdigit():
        n = int(size)
        size_score = 1 if n >= 48 else 2 if n >= 32 else 3
    else:
        size_score = 4
    symbolic_score = 10 if is_symbolic else 0
    return (symbolic_score + size_score, len(path.parts), str(path))


@lru_cache(maxsize=None)
def _candidate_sources_cached(names_tuple):
    out = []
    wanted = set(names_tuple)
    for candidate in root.rglob('*'):
        if not candidate.is_file() or candidate.is_symlink():
            continue
        if candidate.stem not in wanted:
            continue
        if 'places' not in {part.lower() for part in candidate.parts}:
            continue
        out.append(candidate)
    out.sort(key=_place_rank)
    return tuple(out)



def _candidate_sources(names):
    return list(_candidate_sources_cached(tuple(names)))



def _copy_force(src: pathlib.Path, dst: pathlib.Path):
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        for other in dst.parent.glob(dst.stem + '.*'):
            try:
                other.unlink()
            except Exception:
                pass
        shutil.copy2(src, dst)
        return True
    except Exception:
        return False


places_dirs = [p for p in root.rglob('places') if p.is_dir()]
for places in places_dirs:
    files = {p.stem: p for p in places.iterdir() if p.is_file()}
    for names in alias_groups.values():
        source = None
        for name in names:
            if name in files:
                source = files[name]
                break
        if source is None:
            continue
        suffix = source.suffix
        for name in names:
            dst = places / f'{name}{suffix}'
            if not dst.exists():
                try:
                    shutil.copy2(source, dst)
                except Exception:
                    pass

sidebar_overrides = 0
for group, names in alias_groups.items():
    candidates = _candidate_sources(names)
    if not candidates:
        continue
    source = candidates[0]
    source_suffix = source.suffix

    for places in places_dirs:
        size = places.parent.name.lower()
        if size not in small_places_sizes:
            continue
        for name in names:
            dst = places / f'{name}{source_suffix}'
            if _copy_force(source, dst):
                sidebar_overrides += 1

print(f'[OK] Override sidebar places: {sidebar_overrides}')

try:
    from PIL import Image
except Exception:
    Image = None

png_changed = 0
if Image is not None:
    for png in root.rglob('*.png'):
        if png.is_symlink():
            continue
        kind = icon_kind(png)
        try:
            img = Image.open(png).convert('RGBA')
        except Exception:
            continue

        data = list(img.getdata())
        color_cache = {}
        changed = False
        new_data = []

        for pixel in data:
            if pixel in color_cache:
                mapped = color_cache[pixel]
            else:
                r, g, b, a = pixel
                if a == 0:
                    mapped = pixel
                else:
                    nr, ng, nb = [int(round(v)) for v in remap_rgb((r, g, b), kind)]
                    mapped = (nr, ng, nb, a)
                color_cache[pixel] = mapped
            if mapped != pixel:
                changed = True
            new_data.append(mapped)

        if changed:
            img.putdata(new_data)
            img.save(png)
            png_changed += 1

print(f'[OK] SVG ricolorati: {svg_changed}')
if Image is None:
    print('[WARN] Pillow non disponibile: PNG lasciati invariati')
else:
    print(f'[OK] PNG ricolorati: {png_changed}')
