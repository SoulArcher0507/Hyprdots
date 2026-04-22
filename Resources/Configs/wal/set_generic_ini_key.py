#!/usr/bin/env python3
import configparser
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 5:
        print("Usage: set_generic_ini_key.py <file> <group> <key> <value>", file=sys.stderr)
        return 1

    path = Path(sys.argv[1]).expanduser()
    group = sys.argv[2]
    key = sys.argv[3]
    value = sys.argv[4]

    cfg = configparser.RawConfigParser()
    cfg.optionxform = str
    if path.exists():
        cfg.read(path, encoding='utf-8')
    if not cfg.has_section(group):
        cfg.add_section(group)
    cfg.set(group, key, value)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8') as f:
        cfg.write(f, space_around_delimiters=False)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
