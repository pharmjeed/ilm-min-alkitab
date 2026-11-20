# ARCHITECTURE — «علم من الكتاب» (iOS, SwiftUI)

SwiftUI, iOS 17+, Swift 5 language mode, XcodeGen (`project.yml`). No third-party code yet
(Google Sign-In will be added via Swift Package Manager when the account feature is built).

## Layout
```
App/
  IlmApp.swift            @main, RootView (onboarding gate), MainTabView (3 tabs), Route (CI launch args)
  Theme/                  Theme.swift (palette = the site's tokens, AppFont, Num), BrandMark.swift
  Packs/                  PackStore (bundled `packs/` folder + downloaded versions), Models (contract mirror)
  Features/
    Onboarding/           notifications-only first launch
    Home/                 the two treasures
    Names/                mirror of the website's names pages (see below)
    Sunan/                mirror of the website's /sunan pages
    Saved/, More/, Account/
Resources/                Fonts (Thmanyah, Amiri), Assets.xcassets (AppIcon, LaunchBackground)
assets/packs/<section>/   bundled content snapshot (*.pack = JSON) — written ONLY by the platform's app:packs
ci/                       screens.sh + routes.txt (CI screenshots)
```

## Content
Contract: platform `lib/app-packs/types.ts`. Swift mirror: `App/Packs/Models.swift` (decode only what is read).
- names: `index.json` (names, doors, situations, inner types, pages, nameOfDay) + `chunk-NN.json` (NameDetail: meaning,
  teaches, whenRecall, whenPray, summary, verses with prev/next/context/reason/adds, hadiths, situations with scoped
  evidence). The producer already applied the website's display rules.
- sunan: `index.json` (domains, needs, states, stars, macro, pairs, methodology, chunk refs) + `need-NN[-p].json`.
- Sync (to build): GET `/api/app/v1/manifest`; for a newer section version download each file from
  `/api/app/v1/packs/<section>/<version>/<file>`, verify sha256, move into Application Support/packs/<section>/<version>/,
  then set `packs.active.<section>` and clear PackStore's cache. Any failure keeps the current version.

## Names section = the website
Screens map 1:1 to the site's routes and reuse its wording and order:
`/` (names home) → `/feel` (16 doors) → `/feel/<door>` → `/feel/<door>/<situation>` → `/feel/<door>/<situation>/<id>`
(the name inside the situation) · `/names` (all names) · `/names/<id>` (tabs: الآيات · في السنة · ماذا يعلّمني ·
متى أستحضره · متى أدعو به · الزبدة) · `/feel/anfus` · `/ask` (POST `/api/ask/instant`).

## Daily logic (must match the site)
- name of day: `utcDay = floor(epochMs / 86_400_000)`; `sequential_by_date` → `names[utcDay % names.count]`.
- morning notification: rolling 30 local notifications at the chosen time, each opening that day's name.
