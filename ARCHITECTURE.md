# ARCHITECTURE — «علم من الكتاب»

Expo SDK 58 · React Native 0.88 · React 19.3 · TypeScript 6 (strict) · expo-router (files in `src/app/`).
Must run in **Expo Go** (owner tests on his phone) and as an EAS build; the **web** target is used for
automated verification (`npx expo start --web`, `npx expo export -p web`, `web.output: "single"`).

## 1. Sections and screens

Two independent sections. No cross-links between names and sunan in this version.

### Tabs (`src/app/(tabs)/_layout.tsx`, JS `Tabs` from expo-router — NOT NativeTabs)
Order as seen by the reader from right to left:

| file | label | content |
|---|---|---|
| `(tabs)/index.tsx` | «يومي» | Hijri + Gregorian date; «اسم اليوم» card → `/n/<id>`; «سنّة اليوم» card → `/s/item/<id>?fp=&st=` (`sunnahItemHref`); two big entry cards «ماذا تشعر الآن؟» (→ names tab) and «ماذا تحتاج؟» (→ sunan tab); a one-time card «فعّل تذكير الصباح» until enabled or dismissed |
| `(tabs)/names.tsx` | «الأسماء» | «ماذا تشعر الآن؟» door cards (16) · «أو ابدأ من قلبك» → «ما بأنفسهم» (inner types) · «اسأل عن موقفك» box (→ `/n/ask`) · «كل الأسماء» (→ `/n/all`) · search over names & situations |
| `(tabs)/sunan.tsx` | «السنن» | «ماذا تحتاج؟» domain cards (12) · search over needs/states (titles, summaries, «كلمات البحث») · links «السنن الكبرى» / «السنن المتقابلة» / «المنهج والحدود» |
| `(tabs)/saved.tsx` | «محفوظاتي» | saved names, saved verses (name + verse), saved sunan items; empty state |
| `(tabs)/more.tsx` | «المزيد» | theme (تلقائي/داكن/فاتح), text size (عادي/كبير/أكبر), morning reminder (on/off + time), content status (versions, last check, «تحقّق من التحديث»), «عن التطبيق», «منهج الأسماء» (`/page/methodology`), «عن المنصة» (`/page/about`) |

### Names stack (`src/app/n/…`) — mirrors the website's «ماذا تشعر الآن» and name pages
| route | screen |
|---|---|
| `n/door/[door].tsx` (door = Door.id) | h1 «أيُّ حالٍ أقرب إلى ما تعيشه؟», door label + lead; situation rows (situation headline, small label, «N أسماء ←») |
| `n/sit/[sid].tsx` | situation headline + label; «ادعُ الله بهذه الأسماء — N اسمًا:»; name rows (name, excerpt, «N آيات · M أحاديث»); a row opens `/n/sit/<sid>/<id>` if it has evidence, else `/n/<id>` |
| `n/sit/[sid]/[id].tsx` | the name inside the situation: «لهذا الموقف من «X»:», scoped verses («من القرآن» = direct, «وتؤيّده» = support) and hadiths («من السنة»), each with headline + bridge; link «كل مواضع «X» ←» (`/n/<id>`); «→ بقية الأسماء عند {label}» |
| `n/all.tsx` | all names (Excel order) with search box; filter chips by `category` when present |
| `n/[id].tsx` | name page: hero (kicker «الاسم رقم N», name, stats «N موضعًا · M سورة · K حديثًا»), tabs «الآيات», «في السنة», «ماذا يعلّمني», «متى أستحضره», «متى أدعو به», «الزبدة»; «ادعُ به حين:» situation chips; prev/next; favourite + share |
| `n/inner/[slug].tsx` | «ما بأنفسهم» type → its situations (صريح first) |
| `n/ask.tsx` | «اسأل عن موقفك»: text box → POST `{API}/api/ask/instant` → 1–2 matches («أقرب حالٍ لما وصفت:» / «لعلّ حالك إحدى هاتين — اختر الأقرب:») → `/n/sit/<sid>`; offline / limit / error messages in Arabic |

### Sunan stack (`src/app/s/…`)
| route | screen |
|---|---|
| `s/domain/[did].tsx` | domain title; its needs grouped «ما تعمله» (kind do) and «ما تتجنّبه» (kind avoid, `neg` accent); row: need title, «N حالًا · M سنّة» |
| `s/need/[nid].tsx` | need title (+ «علاجه في: X» link for avoid needs); states in order: title, summary (2 lines), «N سنّة» |
| `s/state/[stid].tsx` | state title; «N سنّة، المختار منها أولًا»; representative items with ★ first (stable), then the rest in sheet order; card: badge «ابدأ بهذه», easy line, grade/srcLabel, «+k بمعناها»; for avoid states the remedy link |
| `s/item/[id].tsx` (query `fp`, optional `st` = state hint; build links with `sunnahItemHref()` from `src/lib/links.ts`) | easy line; «طريقة التطبيق»; full text: Sunnah → «…» Amiri with cause (gold) / result (green) runs; Quran → each ayah in ﴿﴾ with its (n), highlights cut at ayah boundaries; meta line (narrator · ref · grade · muhaddith); «التخريج», «باب الحديث», «روايات أخرى»; members «بمعناها» list; «مداخل أخرى» chips → needs; dorar link «الحديث في الدرر السنية ↗»; favourite + copy + share. If `id` is unknown in the current version, resolve by `fp`. |
| `s/macro.tsx` | «السنن الكبرى»: cards (title, cause → result, verses ﴿﴾, hadith refs) grouped by domain |
| `s/pairs.tsx` | «السنن المتقابلة»: positive vs negative with refs, then pairNotes |
| `s/method.tsx` | «المنهج والحدود»: methodology blocks (headings bold) |

### Other
- `src/app/page/[slug].tsx` — `about` | `methodology` markdown from the names index.
- `+not-found.tsx` — «الصفحة غير موجودة».

Every stack screen hides the native header (`headerShown: false`) and renders our own `ScreenHeader`
(back pill «→ رجوع» at the start = right edge, title) so the look is identical in Expo Go, builds and web.

## 2. Folder ownership

```
src/app/                 routes only (thin; logic lives in src/lib / src/features)
src/components/ui/       design-system primitives (foundation owner)
src/components/brand/    LogoMark etc. (brand owner)
src/features/names/      names screens' components + selectors        (names owner)
src/features/sunan/      sunan screens' components + selectors        (sunan owner)
src/features/daily/      home, notifications, saved, more              (daily owner)
src/lib/packs/           pack contract (types.ts — DO NOT EDIT), readers, cache, sync  (foundation)
src/lib/                 pure TS helpers: arabic normalize, count words, daily pickers, hijri, markdown-lite
src/hooks/               shared hooks (foundation)
src/theme/               tokens, ThemeProvider, fonts (foundation)
assets/packs/<section>/  bundled snapshot (*.pack) — written ONLY by the platform's `app:packs` script
assets/fonts/            OTF/TTF
scripts/                 node scripts (bundle manifest generator, icon generator)
```
Pure modules in `src/lib/**` must not import react-native/expo so vitest can test them in Node.

## 3. Data layer

Contract: `src/lib/packs/types.ts` (identical copy of the platform's `lib/app-packs/types.ts`).

- **Bundled snapshot:** `assets/packs/names/*.pack`, `assets/packs/sunan/*.pack` (`.pack` is in `metro.config.js` `resolver.assetExts`). `npm run packs:bundle` runs `scripts/gen-bundled.mjs`, which writes `src/lib/packs/bundled.ts`:
  `export const BUNDLED = { names: { version, files: { "index.json": require("../../../assets/packs/names/index.pack"), … } }, sunan: {…} }`.
- **Reading:** `readPackText(section, file)` → active downloaded version if present (`Paths.document/packs/<section>/<version>/<file>`, pointer `Paths.document/packs/active.json`), else the bundled asset (`Asset.fromModule(id).downloadAsync()` then `new File(localUri).text()` on native; `fetch(asset.uri)` on web — `*.web.ts` variant).
- **Cache:** parsed JSON memoised per (section, version, file). Chunks are loaded lazily (a names chunk holds several names; «الله» is alone in its chunk ≈3 MB; sunan chunks ≤ ~1.2 MB, one per need or part of a need).
- **API (src/lib/packs/store.ts):** `getNamesIndex()`, `getNameDetail(id)`, `getSunanIndex()`, `getSunanChunkForState(stateId)`, `getSunnahItem(id, fp?, stateHint?)` (pass the state whenever known: «بمعناها» members are not in the index); plus `onPacksChanged(cb)` and a `dataEpoch` counter.
- **Hooks (src/hooks/use-data.ts):** `useNamesIndex()`, `useNameDetail(id)`, `useSunanIndex()`, `useStateItems(stateId)`, `useSunnahItem(id, fp)` → `{ data, error, loading }`; they re-run when `dataEpoch` changes.
- **Sync (src/lib/packs/sync.ts):** at launch (after first render) and on «تحقّق من التحديث»: GET `{API}/api/app/v1/manifest`; for each section whose `version` ≠ active and `schema` ≤ app schema: download every file to a temp dir (`File.downloadFileAsync`) from `{API}/api/app/v1/packs/<section>/<version>/<file>`, verify sha256 (`file.digest('SHA-256')` hex), then move into `packs/<section>/<version>/`, write `active.json`, delete older versions, bump `dataEpoch`. Any failure leaves the current version untouched. On web: no download (bundled only). `API = "https://asma-platform-nine.vercel.app"` in `src/lib/config.ts`. A missing/404 manifest is not an error (feature not deployed yet).
- **Favourites keys:** name → `id`; verse → `{nameId, s, a}` (stable across renumbering); sunnah → `{id, fp, easy, stateId?}` (resolve by `fp` after an update; `stateId` is the lookup hint).

## 4. Daily logic (must match the website)
- `utcDay(date) = Math.floor(date.getTime() / 86_400_000)`.
- «اسم اليوم»: `nameOfDay.mode` — `sequential_by_date` → `names[d % names.length]`; `random_daily` → mulberry32 seeded `d*7919` → `names[floor(r()*len)]`; `fixed` → `fixedId` or names[0]. (Copy the platform's `lib/content/daily.ts` algorithm exactly.)
- «سنّة اليوم»: `stars[d % stars.length]` from the sunan index.
- Hijri: `Intl.DateTimeFormat('ar-SA-u-ca-islamic-umalqura', {day:'numeric', month:'long', year:'numeric'})`; if `resolvedOptions().calendar !== 'islamic-umalqura'` show only the Gregorian date (`ar` long format with Western digits via `-u-nu-latn`).
- **Morning reminder** (expo-notifications, local only): enabling asks permission (Android channel «تذكيرات» first). Schedule a rolling window of 30 one-off DATE notifications at the chosen local time (default 07:00): title «اسم اليوم: {name}», body = the name card excerpt (≤ 140 chars), `data.url = "/n/<id>"` computed with the same nameOfDay for that day. Re-schedule on enable, time change, app becoming active, and packs change. Tapping opens the URL (root layout listener + `getLastNotificationResponse`). Web: show «التذكير يعمل في التطبيق على الجوال».

## 5. Visual identity (from the platform's `app/globals.css`)

Dark (default): bg `#0D1F1F`, surface `#122828`, surface2 `#183333`, text/cream `#F7ECD6`, muted `rgba(247,236,214,.62)`, gold `#D4A449`, emerald `#2F6B5E`, line `rgba(212,164,73,.22)`, error `#B4443C`, info `#3E7C8A`, neg (avoid) `#C9826B`, result-green `#8BE0A8` (sunan result runs; cause runs use gold).
Light: bg `#F5E9D0`, surface `#FBF3E3`, surface2 `#F1E3C6`, text `#0D1F1F`, muted `rgba(13,31,31,.64)`, gold `#846008`, emerald `#2F6B5E`, line `rgba(184,134,11,.28)`, neg `#A2482B`, result-green `#1F7A4D`.
Gold alpha helpers: border 35% on verse/door cards, 45% chips, 50% back pill, 60% bridge-box start border; fill 5% (bridge box, chips), 10% (hover/notice).

Type: body **Thmanyah Sans** (Regular/Medium/Bold); headings **Thmanyah Serif Display** (Medium/Bold); Quran & hadith only **Amiri** (Regular/Bold). Sizes: caption 12, small 14, body 16 (line-height 28), lead 20, h3 20, h2 25.6, h1 33.6, hero 44.8. Quran 24 (line-height ≈ 50), neighbouring verses 18 muted; hadith 19 (line-height 40). All sizes multiplied by the user text scale (1 / 1.15 / 1.3).
Shape: 4-pt grid, page padding 16, cards radius 12 (door/hero 16, pills 999), 1px `line` borders, no shadows. Touch targets ≥ 44.
Verse card: border gold35, surface fill; header «الموضع i من N» + «[{surah}: {ayah}]» gold; optional bridge box (start border gold60, gold5 fill, headline bold gold, note cream); main verse ﴿…﴾; sections titled bold gold 16: «القصة», «سبب ذكر الاسم», «ماذا يضيف هذا الموضع؟»; collapsible previous/next verse; draft badge «شرحٌ قيد المراجعة».
Hadith card: border emerald 50%; header «الشاهد i من N» + grade; text «…» Amiri; doc line `{source} ({ref}) — عن {narrator} — الدرجة: {grade}`; sections «المشهد (القصة)», «لماذا جاء الاسم هنا؟», «ماذا يضيف هذا الشاهد؟»; folds after ~6 lines «إظهار المزيد ▾».
Sunnah card: border line; ★ badge «ابدأ بهذه» (gold fill, bg text, radius 6); avoid items get a 3px `neg` start border.
Arrows: «←» open/forward, «→» back, «›» breadcrumb, «▾/▴» expand, «↗» external. Numbers: Western digits. Count words: port the platform's `lib/arabic/count.ts` (`arabicCount`) into `src/lib/arabic/count.ts`.
Light markdown: name texts may contain `**bold**` and line breaks — render bold runs, keep line breaks (`src/lib/markdown-lite.ts` + `RichText` component). Pages (about/methodology) are markdown: headings, paragraphs, lists, bold.

## 6. RTL
- Builds: `expo-localization` plugin `{ supportsRTL: true, forcesRTL: true, supportedLocales: { ios: ["ar"], android: ["ar"] } }`.
- Everywhere (Expo Go on a non-Arabic phone, web): root `<View style={{ flex: 1, direction: "rtl" }}>`; web `dir="rtl"` on the document.
- Use `flexDirection: "row"` (never `row-reverse`), `marginStart/End`, `paddingStart/End`, `start/end` — never left/right.
- Text alignment lives only in `AppText`: `textAlign: I18nManager.isRTL ? "left" : "right"`, `writingDirection: "rtl"`.
- Directional glyphs are text arrows from §5 (no mirrored icons needed).

## 7. Platform endpoints used by the app
- `GET /api/app/v1/manifest` → `AppManifest` (types.ts).
- `GET /api/app/v1/packs/<section>/<version>/<file>` → the file bytes (immutable).
- `POST /api/ask/instant` `{question}` (3–600 chars) → `{ matches: {general, label, situation, href, count, general_slug?, sub_slug?}[], how }`; 429 = limit («بلغت الحد المسموح…» comes in `error`). Map to a situation by `sub_slug` (or the last path segment of `href`, URI-decoded).

## 8. Quality bar
- `npm run typecheck`, `npm run lint` (expo lint), `npm test` (vitest over `src/lib/**`), `npx expo export -p web` all pass.
- No `any` without a comment. No console noise in production paths.
- Lists use `FlatList`/`FlashList`-free plain `FlatList` with stable keys; long screens use `ScrollView` only when bounded.
- Never block the UI thread with huge synchronous work on startup: only the two indexes are read at launch.
