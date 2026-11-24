"""Owner's «رحلة الحسنى» map (bundler-saved HTML template) → Swift data for the app's names-section introduction.

Texts are taken from the owner's file as written (digits shown as Western digits, as everywhere in the app).
Every verse is checked against the platform's quran.json and must match it letter for letter; consecutive verses
are joined with « * » as in content.json.
"""
import sys, re, json, html

tpl_path, quran_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(tpl_path, encoding="utf-8").read()
t = re.sub(r"<style[^>]*>.*?</style>", "", t, flags=re.S)
quran = json.load(open(quran_path, encoding="utf-8"))["surahs"]
surahs = quran if isinstance(quran, dict) else {str(s["no"]): s for s in quran}
by_name = {s["name"]: s for s in surahs.values()}

IND = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def text(fragment):
    x = re.sub(r"<br\s*/?>", "\n", fragment)
    x = html.unescape(re.sub(r"<[^>]+>", "", x))
    return re.sub(r"[ \t]+", " ", x).strip()


def west(s):
    return s.translate(IND).replace("–", "-")


# the stations' names, in order, from the map's pills «١ · نور الأسماء»
pills = [text(p) for p in re.findall(r'padding: 4px 26px">(.*?)</span>', t)]
names = [p.split("·", 1)[1].strip() for p in pills]
assert len(names) == 5, pills

# the lead under the title
m = re.search(r"«الحسنى» في القرآن.*?</p>", t, re.S)
lead = west(text(m.group(0)))
lead = re.sub(r"\s+", " ", lead)
assert lead.startswith("«الحسنى» في القرآن 17 موضعًا."), lead

cards = re.split(r'<div style="width: 560px; flex-shrink: 0;', t)[1:]
assert len(cards) == 6, len(cards)


def verses_of(card):
    out = []
    for blk in re.findall(r"<div>(.*?)</div>", card, re.S):
        if "Amiri" not in blk:
            continue
        label = re.search(r'^<span[^>]*font-weight: 700[^>]*>(.*?)</span>', blk)
        v = text(re.search(r"<p[^>]*>(.*?)</p>", blk, re.S).group(1))
        ref = text(re.findall(r"<span[^>]*>(.*?)</span>", blk)[-1])
        out.append((text(label.group(1)) if label else None, v, ref))
    return out


def check_verse(v, ref):
    """Returns (verse text from quran.json joined with « * », «السورة: آية[-آية]», note or None)."""
    ref = west(ref)
    note = None
    if "·" in ref:
        ref, note = [x.strip() for x in ref.split("·", 1)]
    sname, ayat = [x.strip() for x in ref.split(":")]
    s = by_name[sname]
    if "-" in ayat:
        a, b = map(int, ayat.split("-"))
        nums = list(range(a, b + 1))
    else:
        nums = [int(ayat)]
    assert v.startswith("﴿") and v.endswith("﴾"), v
    parts = [p.strip() for p in v[1:-1].split("۝")]
    want = [s["ayat"][str(n)] for n in nums]
    if parts != want:
        raise SystemExit("verse mismatch %s\n file: %s\n quran: %s" % (ref, parts, want))
    return " * ".join(want), "%s: %s" % (sname, ayat), note


stations = []
total = 0
for i, card in enumerate(cards[:5]):
    head = re.findall(r"<span[^>]*>(.*?)</span>", card)[:2]
    verb, count = text(head[0]), west(text(head[1]))
    side = "طريق جانبي" in count
    title = text(re.search(r"<h3[^>]*>(.*?)</h3>", card, re.S).group(1))
    body = text(re.search(r'<p style="margin: 0; font-size: 21px[^>]*>(.*?)</p>', card, re.S).group(1))
    vs = []
    for label, v, ref in verses_of(card):
        vt, r, note = check_verse(v, ref)
        vs.append({"label": label, "text": vt, "ref": r, "note": note})
        total += 1
    do = text(re.search(r"ماذا تعمل؟ </span><span[^>]*>(.*?)</span>", card, re.S).group(1))
    gain = text(re.search(r"كيف تستفيد؟ </span><span[^>]*>(.*?)</span>", card, re.S).group(1))
    stations.append(dict(n=i + 1, name=names[i], verb=verb, count=count, side=side, title=west(title),
                         text=west(body), verses=vs, doIt=west(do), gain=west(gain)))

end = cards[5]
end_kicker = text(re.search(r'<span style="font-size: 24px; font-weight: 700">(.*?)</span>', end).group(1))
end_title = text(re.search(r"<h3[^>]*>(.*?)</h3>", end, re.S).group(1))
end_text = text(re.search(r'<p style="margin: 0; font-size: 26px[^>]*>(.*?)</p>', end, re.S).group(1))
summary_head = text(re.search(r'<span style="font-size: 22px; font-weight: 700">(.*?)</span>', end).group(1))
summary = [text(x) for x in re.findall(r'<span style="(?:background: #0D1F1F|border: 2px dashed)[^"]*">(.*?)</span>', end)]
closing = text(re.search(r"<p style=\"margin: 8px 0 0[^>]*>(.*?)</p>", end, re.S).group(1))
foot = text(re.search(r"<p[^>]*>(الإحصاء للفظ.*?)</p>", t, re.S).group(1))
foot = west(foot.split(" · منصة")[0])
assert len(summary) == 5 and summary_head == "خلاصة الرحلة", summary

# the footnote's «إحدى الحسنيين» is a word of التوبة 52, quoted as a word — make sure it is in the verse
assert "إِحْدَى الْحُسْنَيَيْنِ" in surahs["9"]["ayat"]["52"]


def sw(s):
    if s is None:
        return "nil"
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


L = []
L.append("// Generated from the owner's map «رحلة الحسنى» (2026-11-24) by journey_gen.py — do not edit by hand.")
L.append("// Every verse was checked letter for letter against the platform's data/quran.json.")
L.append("")
L.append("extension Journey {")
L.append("    static let husna = Journey(")
L.append("        title: %s," % sw("رحلة الحسنى"))
L.append("        lead: %s," % sw(lead))
L.append("        stations: [")
for s in stations:
    L.append("            JourneyStation(")
    L.append("                n: %d, name: %s, verb: %s, count: %s, side: %s," % (s["n"], sw(s["name"]), sw(s["verb"]), sw(s["count"]), "true" if s["side"] else "false"))
    L.append("                title: %s," % sw(s["title"]))
    L.append("                text: %s," % sw(s["text"]))
    L.append("                verses: [")
    for v in s["verses"]:
        L.append("                    JourneyVerse(label: %s, text: %s, ref: %s, note: %s)," % (sw(v["label"]), sw(v["text"]), sw(v["ref"]), sw(west(v["note"]) if v["note"] else None)))
    L.append("                ],")
    L.append("                doIt: %s," % sw(s["doIt"]))
    L.append("                gain: %s" % sw(s["gain"]))
    L.append("            ),")
L.append("        ],")
L.append("        endKicker: %s," % sw(end_kicker))
L.append("        endTitle: %s," % sw(end_title))
L.append("        endText: %s," % sw(end_text))
L.append("        summaryTitle: %s," % sw(summary_head))
L.append("        summary: [%s]," % ", ".join(sw(x) for x in summary))
L.append("        closing: %s," % sw(closing))
L.append("        footnote: %s" % sw(foot))
L.append("    )")
L.append("}")
open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("stations", len(stations), "verses", total, "| lead:", lead)
for s in stations:
    print(" ", s["n"], s["verb"], "·", s["name"], "|", s["count"], "|", len(s["verses"]), "verses", "| side" if s["side"] else "")
print("end:", end_kicker, end_title, "|", summary, "|", closing.replace("\n", " / "))
print("foot:", foot)
