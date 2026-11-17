# Brand — «علم من الكتاب»

The app's mark is the eight-pointed **«ربع الحزب»** star — the sign that marks the quarters of a
hizb in the mushaf — drawn in the platform's language (gold strokes on emerald-night, no fill, a
centre dot). It is a sibling of the platform mark (three nested squares at 0°/22.5°/45°,
`../New folder/brand/logo.svg`): same palette, stroke style, centre dot and opacity hierarchy.
**No text inside the mark.**

## Geometry (120-unit box, centre 60,60)

| element | spec |
|---|---|
| square A | corners on a circle of radius **P = 50**, axis-aligned: `95.36,24.64 95.36,95.36 24.64,95.36 24.64,24.64` |
| square B | same square turned 45°: `110,60 60,110 10,60 60,10` |
| stroke | **6**, `stroke-linejoin="miter"` (crisp star points; tips reach r ≈ 54.24) |
| inner ring | r **16**, stroke **3.25**, stroke-opacity **0.85** |
| centre dot | r **5**, filled |

**Compact variant** (`mark-compact.svg`, used by `LogoMark` below 28 dp and for the favicon): P = 52,
stroke 8.5, no ring, dot r 7.5 — stays readable at 16–24 px.

Colours: dark `#D4A449` on `#0D1F1F` · light `#846008` on `#F5E9D0`. `mark.svg` and
`mark-compact.svg` use `currentColor`.

The React Native component `src/components/brand/LogoMark.tsx` draws exactly these numbers with
`react-native-svg` — change both together.

## Files

| file | what |
|---|---|
| `mark.svg`, `mark-compact.svg` | transparent, `currentColor` |
| `icon.svg` | 1024, rounded-square night background (rx 184) — for web/store artwork |
| `icon-fullbleed.svg` | 1024, square night background — source of `assets/images/icon.png` (iOS masks the corners itself; the PNG is RGB, no alpha channel) |
| `adaptive-foreground.svg` | 1024 transparent, mark radius 0.24 × canvas (diameter ≈ 0.48; Android safe circle is 66/108 ≈ 0.61) → `android-icon-foreground.png` |
| `adaptive-background.svg` | solid `#0D1F1F` → `android-icon-background.png` (RGB) |
| `monochrome.svg` | white mark, same placement as the foreground → `android-icon-monochrome.png` (Android 13+ themed icons) |
| `splash.svg` / `splash-light.svg` | transparent 1024, star spans 80 % of the box, gold `#D4A449` / `#846008` → `assets/images/splash-icon.png` / `splash-icon-light.png` (here) |
| `favicon.svg` | 48 px compact mark on a rounded night tile → `assets/images/favicon.png` |

### `app.json` values (owned by whoever edits `app.json`)

Applied as of 2026-11-17: `icon` / `ios.icon` → `icon.png`, adaptive icon on `#0D1F1F`, favicon,
and an always-dark splash (`splash-icon.png` on `#0D1F1F`, `imageWidth` 200). The light splash
below is optional:

```jsonc
"icon": "./assets/images/icon.png",
"ios": { "icon": "./assets/images/icon.png" /* never the template's "./assets/expo.icon" */ },
"android": { "adaptiveIcon": {
  "backgroundColor": "#0D1F1F",
  "foregroundImage": "./assets/images/android-icon-foreground.png",
  "backgroundImage": "./assets/images/android-icon-background.png",
  "monochromeImage": "./assets/images/android-icon-monochrome.png" } },
"web": { "favicon": "./assets/images/favicon.png" },
["expo-splash-screen", {
  "image": "./assets/brand/splash-icon-light.png", "backgroundColor": "#F5E9D0",
  "dark": { "image": "./assets/images/splash-icon.png", "backgroundColor": "#0D1F1F" },
  "imageWidth": 200 }]
```
(For an always-dark splash use `splash-icon.png` + `#0D1F1F` and drop `dark`.)

## Regenerating the PNGs

The renderer is **not** an app dependency. Needs **Node 18 or newer** (the script uses
`zlib.crc32` on Node ≥ 20.15 / 22.2 and a built-in table CRC-32 otherwise; both give byte-identical
PNGs). In any scratch folder:

```bash
npm init -y && npm i @resvg/resvg-js@2
# save the script below as gen.mjs, then:
node gen.mjs ./out ./preview.png       # writes out/assets/brand/* and out/assets/images/*
```

Then copy `out/assets/brand/*` → `assets/brand/` and the six PNGs in `out/assets/images/` →
`assets/images/` (on the owner's PC, Windows Defender blocks node from overwriting existing PNGs
on the Desktop, so copy with PowerShell `Copy-Item` or Explorer). `preview.png` shows the iOS mask,
Android circle/squircle/themed masks, both splash screens, the favicon and UI sizes 16–64 px.

### gen.mjs

```js
// Brand generator for «علم من الكتاب».
// Usage: node gen.mjs <outRoot> <previewPng>
//   <outRoot> receives assets/brand/* and assets/images/* (same layout as the app). Write to a
//   staging folder and copy into the app afterwards (on this PC, Defender blocks node from
//   overwriting existing PNGs on the Desktop; Copy-Item from PowerShell is allowed).
// Needs only @resvg/resvg-js (installed in this scratch folder, never in the app). Node 18+:
// zlib.crc32 exists only from Node 20.15 / 22.2, so a table-based fallback is used before that.
import { Resvg } from "@resvg/resvg-js";
import { mkdirSync, readFileSync, writeFileSync as fsWrite } from "node:fs";
import * as zlib from "node:zlib";
import { join } from "node:path";

const { deflateSync } = zlib;
const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = typeof zlib.crc32 === "function" ? zlib.crc32 : (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

const APP = process.argv[2];
const PREVIEW = process.argv[3];
if (!APP || !PREVIEW) throw new Error("usage: node gen.mjs <outRoot> <previewPng>");

// Windows: a watcher/indexer may hold a file for a moment (EPERM/EBUSY) -> retry.
function writeFileSync(path, data) {
  for (let i = 0; ; i++) {
    try { return fsWrite(path, data); } catch (e) {
      if (i >= 20 || !["EPERM", "EBUSY", "EACCES"].includes(e.code)) throw e;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 150);
    }
  }
}

const BRAND = join(APP, "assets", "brand");
const IMAGES = join(APP, "assets", "images");
mkdirSync(BRAND, { recursive: true });
mkdirSync(IMAGES, { recursive: true });

// ---- palette -------------------------------------------------------------
const NIGHT = "#0D1F1F"; // emerald-night (dark bg)
const GOLD = "#D4A449"; // antique gold (dark mode)
const CREAM_BG = "#F5E9D0"; // light bg
const GOLD_LIGHT = "#846008"; // gold for light mode (AA on cream)

// ---- geometry (120-unit design box, centre 60,60) ------------------------
// Rub el Hizb: two equal squares at 0deg and 45deg sharing the centre.
// P = distance from centre to each of the 8 star points.
const FULL = { P: 50, w: 6, ringR: 16, ringW: 3.25, ringOpacity: 0.85, dotR: 5 };
// Compact variant for tiny sizes (< 28 dp, and the 48 px favicon): no ring, heavier stroke, bigger dot.
const COMPACT = { P: 52, w: 8.5, ringR: 0, ringW: 0, ringOpacity: 0, dotR: 7.5 };

const r2 = (n) => String(+n.toFixed(2));
function squarePoints(P, deg) {
  // corners of a square whose corners lie on a circle of radius P, rotated by deg
  // deg = 0 -> axis-aligned square (corners on the diagonals)
  const pts = [];
  for (let k = 0; k < 4; k++) {
    const a = ((deg + 45 + k * 90) * Math.PI) / 180 - Math.PI / 2;
    pts.push(`${r2(60 + P * Math.cos(a))},${r2(60 + P * Math.sin(a))}`);
  }
  return pts.join(" ");
}

/** SVG elements of the mark in the 120 box. color may be "currentColor". */
function markElements(g, color) {
  let s = `<g fill="none" stroke="${color}" stroke-width="${g.w}" stroke-linejoin="miter" stroke-miterlimit="4">`;
  s += `<polygon points="${squarePoints(g.P, 0)}"/>`;
  s += `<polygon points="${squarePoints(g.P, 45)}"/>`;
  if (g.ringR) s += `<circle cx="60" cy="60" r="${g.ringR}" stroke-width="${g.ringW}" stroke-opacity="${g.ringOpacity}"/>`;
  s += `</g>`;
  s += `<circle cx="60" cy="60" r="${g.dotR}" fill="${color}"/>`;
  return s;
}

/** Outer radius of the mark incl. the miter tips (in 120 units). */
const extent = (g) => g.P + (g.w / 2) * Math.SQRT2;

/** Place the mark so its outer radius (incl. miter tips) = R px, centred at (cx, cy). */
function placed(g, color, cx, cy, R) {
  const s = R / extent(g);
  return `<g transform="translate(${r2(cx - 60 * s)} ${r2(cy - 60 * s)}) scale(${+s.toFixed(5)})">${markElements(g, color)}</g>`;
}

const svgDoc = (w, h, body, extra = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"${extra}>\n${body}\n</svg>\n`;

// ---- sizes (fractions of the canvas) -------------------------------------
const ICON_R = 0.335; // iOS / store icon: mark radius incl. tips = 33.5% of canvas
const ADAPTIVE_R = 0.24; // Android foreground: well inside the 66/108 dp safe circle (r = 30.6%)
const SPLASH_R = 0.40; // splash: star spans 80% of the image box (stays inside Android 12's 192/288 circle)
const FAVICON_R = 0.43; // favicon: compact mark on a rounded night tile

// ---- SVG sources -----------------------------------------------------------
const label = ` role="img" aria-label="شعار علم من الكتاب — ربع الحزب"`;
const files = {
  "mark.svg": svgDoc(120, 120, markElements(FULL, "currentColor"), label),
  "mark-compact.svg": svgDoc(120, 120, markElements(COMPACT, "currentColor"), label),
  "icon.svg": svgDoc(1024, 1024, `<rect width="1024" height="1024" rx="184" fill="${NIGHT}"/>\n${placed(FULL, GOLD, 512, 512, 1024 * ICON_R)}`, label),
  "icon-fullbleed.svg": svgDoc(1024, 1024, `<rect width="1024" height="1024" fill="${NIGHT}"/>\n${placed(FULL, GOLD, 512, 512, 1024 * ICON_R)}`, label),
  "adaptive-foreground.svg": svgDoc(1024, 1024, placed(FULL, GOLD, 512, 512, 1024 * ADAPTIVE_R), label),
  "adaptive-background.svg": svgDoc(1024, 1024, `<rect width="1024" height="1024" fill="${NIGHT}"/>`),
  "monochrome.svg": svgDoc(1024, 1024, placed(FULL, "#FFFFFF", 512, 512, 1024 * ADAPTIVE_R), label),
  "splash.svg": svgDoc(1024, 1024, placed(FULL, GOLD, 512, 512, 1024 * SPLASH_R), label),
  "splash-light.svg": svgDoc(1024, 1024, placed(FULL, GOLD_LIGHT, 512, 512, 1024 * SPLASH_R), label),
  "favicon.svg": svgDoc(48, 48, `<rect width="48" height="48" rx="10" fill="${NIGHT}"/>\n${placed(COMPACT, GOLD, 24, 24, 48 * FAVICON_R)}`, label),
};
for (const [name, text] of Object.entries(files)) writeFileSync(join(BRAND, name), text);

// ---- PNG renders -----------------------------------------------------------
// Opaque images are re-encoded as RGB (colour type 2, no alpha channel): stores reject alpha in the icon.
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td) >>> 0);
  return Buffer.concat([len, td, crc]);
}
function encodeRgbPng(width, height, rgba) {
  const row = width * 3 + 1, raw = Buffer.alloc(row * height);
  for (let y = 0; y < height; y++) {
    raw[y * row] = 0; // filter: none
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4, o = y * row + 1 + x * 3;
      if (rgba[i + 3] !== 255) throw new Error(`non-opaque pixel at ${x},${y}`);
      raw[o] = rgba[i]; raw[o + 1] = rgba[i + 1]; raw[o + 2] = rgba[i + 2];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", ihdr), pngChunk("IDAT", deflateSync(raw, { level: 9 })), pngChunk("IEND", Buffer.alloc(0)),
  ]);
}
const render = (svg, width, opaque = false) => {
  const img = new Resvg(svg, { fitTo: { mode: "width", value: width }, font: { loadSystemFonts: false } }).render();
  return opaque ? encodeRgbPng(img.width, img.height, img.pixels) : img.asPng();
};

const outputs = [
  [join(IMAGES, "icon.png"), files["icon-fullbleed.svg"], 1024, true],
  [join(IMAGES, "android-icon-foreground.png"), files["adaptive-foreground.svg"], 1024],
  [join(IMAGES, "android-icon-background.png"), files["adaptive-background.svg"], 1024, true],
  [join(IMAGES, "android-icon-monochrome.png"), files["monochrome.svg"], 1024],
  [join(IMAGES, "splash-icon.png"), files["splash.svg"], 1024],
  [join(IMAGES, "favicon.png"), files["favicon.svg"], 48],
  [join(BRAND, "splash-icon-light.png"), files["splash-light.svg"], 1024],
];
for (const [path, svg, w, opaque] of outputs) writeFileSync(path, render(svg, w, opaque));

// ---- preview sheet (built from the PNG files actually written) -------------
const uri = (p) => `data:image/png;base64,${readFileSync(p).toString("base64")}`;
const img = (p, x, y, w, h, extra = "") => `<image href="${uri(p)}" x="${x}" y="${y}" width="${w}" height="${h}"${extra}/>`;

function squirclePath(x, y, size, n = 5) {
  const a = size / 2, cx = x + a, cy = y + a;
  let d = "";
  for (let i = 0; i <= 360; i += 2) {
    const t = (i * Math.PI) / 180;
    const c = Math.cos(t), s = Math.sin(t);
    const px = cx + a * Math.sign(c) * Math.abs(c) ** (2 / n);
    const py = cy + a * Math.sign(s) * Math.abs(s) ** (2 / n);
    d += `${i === 0 ? "M" : "L"}${r2(px)},${r2(py)} `;
  }
  return d + "Z";
}

const P_ICON = join(IMAGES, "icon.png");
const P_FG = join(IMAGES, "android-icon-foreground.png");
const P_BG = join(IMAGES, "android-icon-background.png");
const P_MONO = join(IMAGES, "android-icon-monochrome.png");
const P_SPLASH = join(IMAGES, "splash-icon.png");
const P_SPLASH_L = join(BRAND, "splash-icon-light.png");
const P_FAV = join(IMAGES, "favicon.png");

const T = (x, y, text, size = 18, fill = "#F7ECD6", anchor = "middle") =>
  `<text x="${x}" y="${y}" fill="${fill}" font-family="Tahoma" font-size="${size}" text-anchor="${anchor}" direction="rtl">${text}</text>`;

let defs = "", body = "";
const S = 240; // tile size
const sheetW = 1720, sheetH = 1080;
body += `<rect width="${sheetW}" height="${sheetH}" fill="#3A3F3F"/>`;

// Row 1 — icons
let x = 40; const y1 = 70;
body += T(sheetW / 2, 42, "معاينة هوية «علم من الكتاب» — ربع الحزب", 24);
// iOS (squircle mask on full-bleed PNG)
defs += `<clipPath id="ios"><path d="${squirclePath(x, y1, S)}"/></clipPath>`;
body += `<g clip-path="url(#ios)">${img(P_ICON, x, y1, S, S)}</g>`;
body += T(x + S / 2, y1 + S + 30, "آيفون — قناع النظام");
x += S + 40;
// raw full-bleed
body += img(P_ICON, x, y1, S, S);
body += T(x + S / 2, y1 + S + 30, "الأيقونة كاملة الحواف");
x += S + 40;
// Android adaptive: visible area = central 72/108 of the canvas
const adaptive = (id, clip, px, py) => {
  const k = S / (1024 * 72 / 108); // tile px per canvas px
  const full = 1024 * k, off = (full - S) / 2;
  defs += `<clipPath id="${id}">${clip}</clipPath>`;
  return `<g clip-path="url(#${id})">${img(P_BG, px - off, py - off, full, full)}${img(P_FG, px - off, py - off, full, full)}</g>`;
};
body += adaptive("circ", `<circle cx="${x + S / 2}" cy="${y1 + S / 2}" r="${S / 2}"/>`, x, y1);
// safe-zone guide (66 dp circle) as a faint dashed ring
body += `<circle cx="${x + S / 2}" cy="${y1 + S / 2}" r="${(S / 2) * (66 / 72)}" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-dasharray="4 6"/>`;
body += T(x + S / 2, y1 + S + 30, "أندرويد دائري — والمنطقة الآمنة");
x += S + 40;
body += adaptive("sq", `<path d="${squirclePath(x, y1, S, 4)}"/>`, x, y1);
body += T(x + S / 2, y1 + S + 30, "أندرويد مربّع مدوّر");
x += S + 40;
// Themed (monochrome) icon on Android 13+: tinted alpha mask on a tonal background
{
  const k = S / (1024 * 72 / 108), full = 1024 * k, off = (full - S) / 2;
  defs += `<clipPath id="mono"><circle cx="${x + S / 2}" cy="${y1 + S / 2}" r="${S / 2}"/></clipPath>`;
  defs += `<filter id="tint" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="0 0 0 0 0.16  0 0 0 0 0.26  0 0 0 0 0.24  0 0 0 1 0"/></filter>`;
  body += `<g clip-path="url(#mono)"><rect x="${x}" y="${y1}" width="${S}" height="${S}" fill="#CFE8DF"/>${img(P_MONO, x - off, y1 - off, full, full, ` filter="url(#tint)"`)}</g>`;
  body += T(x + S / 2, y1 + S + 30, "أندرويد بلون النظام");
}
x += S + 40;
// favicon 1x and 4x (pixelated)
body += img(P_FAV, x, y1, 48, 48);
body += `<image href="${uri(P_FAV)}" x="${x}" y="${y1 + 64}" width="192" height="192" image-rendering="optimizeSpeed"/>`;
body += T(x + 96, y1 + S + 30, "أيقونة المتصفح 48 بكسل");

// Row 2 — splash screens + small sizes
const y2 = 400;
const phone = (px, bg, mark, title) => {
  const W = 260, H = 540; // ~ 390 x 810 dp at 2/3 scale
  const imgW = 200 * (W / 390); // imageWidth 200 dp
  let s = `<rect x="${px}" y="${y2}" width="${W}" height="${H}" rx="34" fill="${bg}" stroke="#111" stroke-width="6"/>`;
  s += img(mark, px + W / 2 - imgW / 2, y2 + H / 2 - imgW / 2, imgW, imgW);
  s += T(px + W / 2, y2 + H + 34, title);
  return s;
};
body += phone(40, NIGHT, P_SPLASH, "شاشة البدء — داكن");
body += phone(340, CREAM_BG, P_SPLASH_L, "شاشة البدء — فاتح");

// small-size ladder of the icon (home screen / settings / spotlight / notification sizes)
let lx = 680; const ly = y2 + 10;
for (const s of [180, 120, 87, 60, 40]) {
  const id = `l${s}`;
  defs += `<clipPath id="${id}"><path d="${squirclePath(lx, ly, s)}"/></clipPath>`;
  body += `<g clip-path="url(#${id})">${img(P_ICON, lx, ly, s, s)}</g>`;
  body += T(lx + s / 2, ly + 180 + 30, String(s), 15);
  lx += s + 28;
}
// mark at UI sizes (1x pixels) on dark and light, switching to compact below 28 like LogoMark "auto"
let mx = 680; const my = y2 + 270;
body += `<rect x="${mx - 20}" y="${my - 20}" width="960" height="110" rx="14" fill="${NIGHT}"/>`;
body += `<rect x="${mx - 20}" y="${my + 110}" width="960" height="110" rx="14" fill="${CREAM_BG}"/>`;
for (const size of [16, 20, 24, 32, 40, 48, 64]) {
  const g = size < 28 ? COMPACT : FULL;
  const R = size / 2;
  body += placed(g, GOLD, mx + R, my + 35, R);
  body += placed(g, GOLD_LIGHT, mx + R, my + 165, R);
  body += T(mx + R, my + 90, String(size), 13, "#F7ECD6");
  mx += size + 46;
}
// lockup approximation (system font; the app uses Thmanyah Serif Display)
body += placed(FULL, GOLD, 1520, my + 35, 22);
body += T(1490, my + 44, "علم من الكتاب", 24, "#F7ECD6", "end");
body += placed(FULL, GOLD_LIGHT, 1520, my + 165, 22);
body += T(1490, my + 174, "علم من الكتاب", 24, NIGHT, "end");

const sheet = `<svg xmlns="http://www.w3.org/2000/svg" width="${sheetW}" height="${sheetH}" viewBox="0 0 ${sheetW} ${sheetH}"><defs>${defs}</defs>${body}</svg>`;
writeFileSync(PREVIEW, new Resvg(sheet, { font: { loadSystemFonts: true, defaultFontFamily: "Tahoma" } }).render().asPng());

// ---- numbers for the RN component -----------------------------------------
console.log(JSON.stringify({
  full: { sq0: squarePoints(FULL.P, 0), sq45: squarePoints(FULL.P, 45), ...FULL },
  compact: { sq0: squarePoints(COMPACT.P, 0), sq45: squarePoints(COMPACT.P, 45), ...COMPACT },
  extentFull: extent(FULL), extentCompact: extent(COMPACT),
}, null, 1));
```
