#!/usr/bin/env python3
import json
import os
import sys
import tempfile
from pathlib import Path


def hex_norm(value: str) -> str:
    value = (value or "").strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"invalid hex color: {value!r}")
    return f"#{value.upper()}"


def h2rgb(value: str) -> tuple[int, int, int]:
    value = hex_norm(value).lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def rgb_triplet(value: str) -> str:
    return ",".join(str(c) for c in h2rgb(value))


def mix_hex(a: str, b: str, t: float) -> str:
    ar, ag, ab = h2rgb(a)
    br, bg, bb = h2rgb(b)
    t = max(0.0, min(1.0, t))
    r = round(ar * (1 - t) + br * t)
    g = round(ag * (1 - t) + bg * t)
    b = round(ab * (1 - t) + bb * t)
    return f"#{r:02X}{g:02X}{b:02X}"


def linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def relative_luminance(value: str) -> float:
    r, g, b = [linear(c / 255) for c in h2rgb(value)]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(a: str, b: str) -> float:
    lighter, darker = sorted((relative_luminance(a), relative_luminance(b)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def contrast_hex(value: str) -> str:
    candidates = ("#0B0F14", "#F5F7FA")
    return max(candidates, key=lambda candidate: contrast_ratio(value, candidate))


def ensure_contrast(value: str, backgrounds: tuple[str, ...], target: float = 4.5) -> str:
    def minimum_ratio(candidate: str) -> float:
        return min(contrast_ratio(candidate, background) for background in backgrounds)

    if minimum_ratio(value) >= target:
        return value

    candidates = ("#0B0F14", "#F5F7FA")
    toward = max(candidates, key=minimum_ratio)
    low, high = 0.0, 1.0
    for _ in range(24):
        mid = (low + high) / 2
        if minimum_ratio(mix_hex(value, toward, mid)) >= target:
            high = mid
        else:
            low = mid
    return mix_hex(value, toward, high)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            tmp.write(content)
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def build_context(palette_path: Path) -> dict[str, str]:
    with palette_path.open(encoding="utf-8") as fh:
        raw = json.load(fh)

    special = raw.get("special", {})
    colors = raw.get("colors", {})
    context = {
        "bg": hex_norm(special["background"]),
        "fg": hex_norm(special["foreground"]),
        "cursor": hex_norm(special["cursor"]),
    }

    for i in range(16):
        context[f"c{i}"] = hex_norm(colors[f"color{i}"])

    context.update({
        "accent": context["c4"],
        "accent2": context["c6"],
        "success": context["c2"],
        "warning": context["c3"],
        "danger": context["c1"],
        "muted": context["c8"],
    })

    context.update({
        "window_bg": mix_hex(context["bg"], context["fg"], 0.06),
        "view_bg": context["bg"],
        "alt_bg": mix_hex(context["bg"], context["c0"], 0.55),
        "panel_bg": mix_hex(context["bg"], context["accent"], 0.10),
        "header_bg": mix_hex(context["bg"], context["accent"], 0.14),
        "button_bg": mix_hex(context["bg"], context["accent"], 0.16),
        "button_alt_bg": mix_hex(context["bg"], context["accent2"], 0.18),
        "tooltip_bg": mix_hex(context["bg"], context["fg"], 0.12),
        "comp_bg": mix_hex(context["bg"], context["accent2"], 0.12),
        "active_title_bg": mix_hex(context["bg"], context["accent"], 0.22),
        "inactive_title_bg": mix_hex(context["bg"], context["fg"], 0.09),
        "selection_bg": context["accent"],
        "selection_alt_bg": context["accent2"],
    })

    context.update({
        "backdrop_bg": mix_hex(context["bg"], context["fg"], 0.04),
        "popover_bg": mix_hex(context["window_bg"], context["fg"], 0.10),
        "dialog_bg": mix_hex(context["window_bg"], context["fg"], 0.08),
        "hover_bg": mix_hex(context["window_bg"], context["accent2"], 0.24),
        "pressed_bg": mix_hex(context["window_bg"], context["accent"], 0.34),
        "trough_bg": mix_hex(context["bg"], context["fg"], 0.10),
        "scrollbar_bg": mix_hex(context["bg"], context["fg"], 0.28),
        "scrollbar_hover_bg": mix_hex(context["bg"], context["fg"], 0.42),
        "sidebar_backdrop_bg": mix_hex(context["comp_bg"], context["bg"], 0.30),
        "secondary_sidebar_backdrop_bg": mix_hex(context["alt_bg"], context["bg"], 0.24),
        "overview_bg": mix_hex(context["bg"], context["accent2"], 0.10),
        "thumbnail_bg": mix_hex(context["bg"], context["fg"], 0.14),
        "active_toggle_bg": mix_hex(context["bg"], context["accent"], 0.28),
    })
    context["selection_fg"] = contrast_hex(context["selection_bg"])
    context["selection_alt_fg"] = contrast_hex(context["selection_alt_bg"])
    context["button_fg"] = contrast_hex(context["button_bg"])
    context["header_fg"] = contrast_hex(context["header_bg"])
    context["active_title_fg"] = contrast_hex(context["active_title_bg"])
    context["hover_fg"] = contrast_hex(context["hover_bg"])
    context["pressed_fg"] = contrast_hex(context["pressed_bg"])
    context["danger_fg"] = contrast_hex(context["danger"])
    context["success_fg"] = contrast_hex(context["success"])
    context["warning_fg"] = contrast_hex(context["warning"])
    context["active_toggle_fg"] = contrast_hex(context["active_toggle_bg"])

    content_surfaces = (
        context["window_bg"],
        context["view_bg"],
        context["popover_bg"],
        context["comp_bg"],
    )
    context["accent_color"] = ensure_contrast(context["accent"], content_surfaces)
    context["accent2_color"] = ensure_contrast(context["accent2"], content_surfaces)
    context["danger_color"] = ensure_contrast(context["danger"], content_surfaces)
    context["success_color"] = ensure_contrast(context["success"], content_surfaces)
    context["warning_color"] = ensure_contrast(context["warning"], content_surfaces)

    for key, value in list(context.items()):
        if isinstance(value, str) and value.startswith("#"):
            context[f"rgb_{key}"] = rgb_triplet(value)

    return context


def render_template(template_path: Path, context: dict[str, str]) -> str:
    content = template_path.read_text(encoding="utf-8")
    for key in sorted(context, key=len, reverse=True):
        content = content.replace(f"{{{{{key}}}}}", context[key])
    return content


def main() -> int:
    if len(sys.argv) != 9:
        print(
            "Usage: render_templates.py <palette.json> <templates_dir> <hypr.lua> <quickshell.json> <kitty.conf> <kde.colors> <gtk.css> <gtk4.css>",
            file=sys.stderr,
        )
        return 1

    palette_path = Path(sys.argv[1])
    templates_dir = Path(sys.argv[2])
    outputs = {
        "hypr-colors.lua.tmpl": Path(sys.argv[3]),
        "quickshell-colors.json.tmpl": Path(sys.argv[4]),
        "kitty-colors.conf.tmpl": Path(sys.argv[5]),
        "kde-dynamic.colors.tmpl": Path(sys.argv[6]),
        "gtk-dynamic.css.tmpl": Path(sys.argv[7]),
        "gtk4-dynamic.css.tmpl": Path(sys.argv[8]),
    }

    context = build_context(palette_path)
    for template_name, output_path in outputs.items():
        atomic_write(output_path, render_template(templates_dir / template_name, context))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
