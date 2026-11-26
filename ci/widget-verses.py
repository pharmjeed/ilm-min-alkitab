#!/usr/bin/env python3
"""Every name's Quran positions for the widgets (owner 2026-11-26: «اجعلها بطريقة تعرض كل المواضع على مر الزمن»).

Reads the bundled names packs (assets/packs/names/chunk-*.pack — the same content the app ships) and writes one small
file per name, gen/widget-verses/<id>.json: [{"s", "surah", "a", "last"?, "text"}] in the name page's order, the ayah
text verbatim. The widget extension reads only the file of the name it shows. Run before `xcodegen generate`.
"""
import glob
import json
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "gen", "widget-verses")
os.makedirs(out, exist_ok=True)
for old in glob.glob(os.path.join(out, "*.json")):
    os.remove(old)

names = 0
verses = 0
for path in sorted(glob.glob(os.path.join(root, "assets", "packs", "names", "chunk-*.pack"))):
    with open(path, encoding="utf-8") as f:
        chunk = json.load(f)
    for n in chunk["names"]:
        rows = []
        for v in n["verses"]:
            row = {"s": v["s"], "surah": v["surah"], "a": v["a"], "text": v["text"]}
            if v.get("last"):
                row["last"] = v["last"]
            rows.append(row)
        with open(os.path.join(out, f"{n['id']}.json"), "w", encoding="utf-8") as f:
            json.dump(rows, f, ensure_ascii=False, separators=(",", ":"))
        names += 1
        verses += len(rows)

if names == 0:
    sys.exit("widget-verses: no names packs found")
print(f"widget-verses: {names} names, {verses} positions -> {out}")
