#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
exts = {".gd", ".tscn", ".godot", ".json", ".md", ".sh", ".svg"}
for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix.lower() not in exts and path.name != "Makefile":
        continue
    data = path.read_bytes()
    if b"\r" not in data:
        continue
    path.write_bytes(data.replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
    print("fixed", path.relative_to(root))
