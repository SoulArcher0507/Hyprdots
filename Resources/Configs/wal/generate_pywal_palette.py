#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path


def hex_norm(value: str) -> str:
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"invalid hex color: {value!r}")
    return f"#{value.upper()}"


def h2rgb(value: str) -> tuple[int, int, int]:
    value = hex_norm(value).lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix_hex(a: str, b: str, t: float) -> str:
    ar, ag, ab = h2rgb(a)
    br, bg, bb = h2rgb(b)
    t = max(0.0, min(1.0, t))
    return "#{:02X}{:02X}{:02X}".format(
        round(ar * (1 - t) + br * t),
        round(ag * (1 - t) + bg * t),
        round(ab * (1 - t) + bb * t),
    )


def color_luma(value: str) -> float:
    r, g, b = h2rgb(value)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def image_colors(image: Path) -> list[str]:
    proc = subprocess.run(
        [
            "magick",
            str(image),
            "-resize",
            "25%",
            "-colors",
            "16",
            "-unique-colors",
            "txt:-",
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    colors = []
    for line in proc.stdout.splitlines():
        for part in line.split():
            if part.startswith("#") and len(part) >= 7:
                colors.append(hex_norm(part[:7]))
                break

    if len(colors) < 8:
        raise RuntimeError(f"not enough colors extracted from {image}")

    return colors


def build_palette(image: Path) -> dict:
    colors = image_colors(image)
    background = colors[0]
    bright = colors[8:14] if len(colors) >= 14 else sorted(colors, key=color_luma)[1:7]
    foreground_seed = colors[14] if len(colors) > 14 else sorted(colors, key=color_luma)[-1]
    foreground = mix_hex(foreground_seed, "#FFFFFF", 0.32)
    muted = mix_hex(foreground, "#000000", 0.30)

    ansi = [background]
    ansi.extend(bright[:6])
    ansi.append(foreground)
    ansi.append(muted)
    ansi.extend(ansi[1:7])
    ansi.append(foreground)

    return {
        "wallpaper": str(image),
        "special": {
            "background": background,
            "foreground": foreground,
            "cursor": foreground,
        },
        "colors": {f"color{i}": ansi[i] for i in range(16)},
    }


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: generate_pywal_palette.py <image> <output.json>", file=sys.stderr)
        return 1

    image = Path(sys.argv[1])
    output = Path(sys.argv[2])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_palette(image), indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
