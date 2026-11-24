"""Unpack a bundler-saved HTML page: print the template's visible text and list manifest entries."""
import sys, re, json, base64, gzip, html
src, outdir = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
def block(t):
    m = re.search(r'<script type="__bundler/%s">(.*?)</script>' % t, s, re.S)
    return m.group(1) if m else None
tpl = block("template")
t = json.loads(tpl)
open(outdir + "/template.html", "w", encoding="utf-8").write(t if isinstance(t, str) else json.dumps(t, ensure_ascii=False))
man = json.loads(block("manifest"))
print("manifest entries:", len(man))
for k, v in list(man.items()):
    mime = v.get("mime") or v.get("type")
    data = v.get("data", "")
    raw = base64.b64decode(data) if data else b""
    if v.get("compressed") or raw[:2] == b"\x1f\x8b":
        try: raw = gzip.decompress(raw)
        except Exception: pass
    print(k[:40], mime, len(raw))
    if mime and ("javascript" in mime or "html" in mime or "json" in mime or "text" in mime):
        open(outdir + "/" + re.sub(r"[^\w.-]", "_", k)[:60] + ".txt", "wb").write(raw)
