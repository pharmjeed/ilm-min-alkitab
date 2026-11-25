"""Owner's «رحلة باسم ربك» map (bundler-saved HTML template, unpacked with unpack_bundle.py) → Swift data.

The second journey of the names section (owner 2026-11-25), after «رحلة الحسنى». Texts are taken from the owner's file
as written (digits shown as Western digits, as everywhere in the app). Every verse is checked against the platform's
quran.json and must match it letter for letter.

usage: python journey_bism_gen.py <template.html> <quran.json> <out.swift> [<out.json>]  (--json: the website's copy)
"""
import sys, re, json, html

tpl_path, quran_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(tpl_path, encoding="utf-8").read()
t = re.sub(r"<style[^>]*>.*?</style>", "", t, flags=re.S)
t = re.sub(r"<script[^>]*>.*?</script>", "", t, flags=re.S)
quran = json.load(open(quran_path, encoding="utf-8"))["surahs"]
surahs = quran if isinstance(quran, dict) else {str(s["no"]): s for s in quran}
by_name = {s["name"]: s for s in surahs.values()}

IND = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


def west(s):
    return s.translate(IND).replace("–", "-")


# the visible text, one block element per line
x = re.sub(r"<br\s*/?>", " ", t)
x = html.unescape(re.sub(r"<[^>]+>", "\n", x))
lines = [re.sub(r"[ \t]+", " ", l).strip() for l in x.split("\n")]
lines = [l for l in lines if l]

title = lines[lines.index("رحلة باسم ربك — خريطة الرحلة") + 1]
assert title == "باسم ربك", title
lead_i = lines.index(title) + 1
lead = west(lines[lead_i] + " " + lines[lead_i + 1] + " " + lines[lead_i + 2])
lead = re.sub(r"\s+", " ", lead)
assert lead == "اسم الله يرافقك من أول عملك إلى أعلى مقامات التعظيم · 29 آية", lead

# the stations start after the last pill of the map («النهاية · …»)
i = next(k for k, l in enumerate(lines) if l.startswith("النهاية ·")) + 1


def check_verse(v, ref):
    ref = west(ref)
    sname, ayat = [p.strip() for p in ref.split(":")]
    s = by_name[sname]
    nums = [int(ayat)] if "-" not in ayat else None
    if nums is None:
        a, b = map(int, ayat.split("-"))
        nums = list(range(a, b + 1))
    assert v.startswith("﴿") and v.endswith("﴾"), v
    parts = [p.strip() for p in v[1:-1].split("۝")]
    want = [s["ayat"][str(n)] for n in nums]
    if parts != want:
        raise SystemExit("verse mismatch %s\n file: %s\n quran: %s" % (ref, parts, want))
    return " * ".join(want), "%s: %s" % (sname, ayat)


stations = []
total = 0
while lines[i] != "نهاية الطريق":
    verb, count, st_title, body = lines[i], west(lines[i + 1]), lines[i + 2], lines[i + 3]
    i += 4
    vs = []
    while lines[i].startswith("﴿"):
        vt, r = check_verse(lines[i], lines[i + 1])
        vs.append({"text": vt, "ref": r})
        i += 2
        total += 1
    assert lines[i] == "ماذا تعمل؟", lines[i]
    do = lines[i + 1]
    assert lines[i + 2] == "كيف تستفيد؟", lines[i + 2]
    gain = lines[i + 3]
    i += 4
    n = int(re.match(r"(\d+)", count).group(1))
    assert n == len(vs), (st_title, count, len(vs))
    stations.append(dict(n=len(stations) + 1, verb=verb, count=count, side="طريق جانبي" in count,
                         title=west(st_title), text=west(body), verses=vs, doIt=west(do), gain=west(gain)))

end_kicker = lines[i]
end_title = lines[i + 1]
end_vt, end_ref = check_verse(lines[i + 2], lines[i + 3])
total += 1
end_text = west(lines[i + 4])
summary_head = lines[i + 5]
assert summary_head == "خلاصة الرحلة", summary_head
summary = lines[i + 6:i + 6 + len(stations)]
foot = west(lines[i + 6 + len(stations)].split(" · منصة")[0])
assert len(stations) == 6 and total == 29, (len(stations), total)
assert foot.startswith("29 آية: 23 موضعًا"), foot


def sw(s):
    if s is None:
        return "nil"
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


L = []
L.append("// Generated from the owner's map «رحلة باسم ربك» (2026-11-25) by journey_bism_gen.py — do not edit by hand.")
L.append("// Every verse was checked letter for letter against the platform's data/quran.json.")
L.append("")
L.append("extension Journey {")
L.append("    static let bism = Journey(")
L.append("        title: %s," % sw(title))
L.append("        lead: %s," % sw(lead))
L.append("        stations: [")
for s in stations:
    L.append("            JourneyStation(")
    L.append("                n: %d, name: \"\", verb: %s, count: %s, side: %s," % (s["n"], sw(s["verb"]), sw(s["count"]), "true" if s["side"] else "false"))
    L.append("                title: %s," % sw(s["title"]))
    L.append("                text: %s," % sw(s["text"]))
    L.append("                verses: [")
    for v in s["verses"]:
        L.append("                    JourneyVerse(label: nil, text: %s, ref: %s, note: nil)," % (sw(v["text"]), sw(v["ref"])))
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
L.append("        closing: \"\",")
L.append("        footnote: %s," % sw(foot))
L.append("        endVerse: JourneyVerse(label: nil, text: %s, ref: %s, note: nil)" % (sw(end_vt), sw(end_ref)))
L.append("    )")
L.append("}")
open(out_path, "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")
print("stations", len(stations), "verses", total, "| lead:", lead)
for s in stations:
    print(" ", s["n"], s["verb"], "|", s["title"], "|", s["count"], "|", len(s["verses"]), "verses", "| side" if s["side"] else "")
print(" end:", end_kicker, "|", end_title, "|", end_ref, "| summary:", summary, "| foot:", foot)

# optional: the same journey as JSON for the website (platform data/journeys/bism.json)
if len(sys.argv) > 4:
    for s in stations:
        s["name"] = ""
        for v in s["verses"]:
            v.update(label=None, note=None)
    json.dump({"slug": "bism", "title": title, "lead": lead, "stations": stations, "endKicker": end_kicker,
               "endTitle": end_title, "endText": end_text, "summaryTitle": summary_head, "summary": summary,
               "closing": "", "footnote": foot,
               "endVerse": {"label": None, "text": end_vt, "ref": end_ref, "note": None}},
              open(sys.argv[4], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("json →", sys.argv[4])
