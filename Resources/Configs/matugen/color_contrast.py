#!/usr/bin/env python3
import sys


def linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: color_contrast.py <hex>", file=sys.stderr)
        return 1

    h = sys.argv[1].lstrip('#')
    r, g, b = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    L = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    print('#0B0F14' if L > 0.45 else '#F5F7FA')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
