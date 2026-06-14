#!/usr/bin/env python3
import sys


def h2rgb(h: str):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: color_mix.py <hex_a> <hex_b> <t>", file=sys.stderr)
        return 1

    a = h2rgb(sys.argv[1])
    b = h2rgb(sys.argv[2])
    t = max(0.0, min(1.0, float(sys.argv[3])))
    res = tuple(round(x * (1 - t) + y * t) for x, y in zip(a, b))
    print('#%02X%02X%02X' % res)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
