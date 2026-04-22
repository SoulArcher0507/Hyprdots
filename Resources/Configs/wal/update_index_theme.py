#!/usr/bin/env python3
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: update_index_theme.py <index.theme> <theme_name>", file=sys.stderr)
        return 1

    p = Path(sys.argv[1])
    name = sys.argv[2]
    text = p.read_text(encoding='utf-8', errors='ignore')
    lines = text.splitlines()
    out = []
    seen_name = seen_comment = seen_inherits = False
    for line in lines:
        if line.startswith('Name='):
            out.append(f'Name={name}')
            seen_name = True
        elif line.startswith('Comment='):
            out.append('Comment=Dynamic icon theme generated from Kora and QS palette')
            seen_comment = True
        elif line.startswith('Inherits='):
            out.append('Inherits=breeze,breeze-dark,hicolor')
            seen_inherits = True
        else:
            out.append(line)
    if not seen_name:
        out.append(f'Name={name}')
    if not seen_comment:
        out.append('Comment=Dynamic icon theme generated from Kora and QS palette')
    if not seen_inherits:
        out.append('Inherits=breeze,breeze-dark,hicolor')
    p.write_text('\n'.join(out) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
