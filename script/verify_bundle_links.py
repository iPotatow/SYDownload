#!/usr/bin/env python3
"""Allow framework links only when their resolved target exists inside the app."""
from pathlib import Path
import sys


def verify(root: Path) -> None:
    root = root.resolve(strict=True)
    for path in root.rglob("*"):
        if path.is_symlink():
            target = path.resolve(strict=True)
            if not target.is_relative_to(root):
                raise ValueError(f"Bundle symlink escapes app: {path}")


if __name__ == "__main__":
    verify(Path(sys.argv[1]))
