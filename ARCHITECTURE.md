# ARCHITECTURE — «علم من الكتاب» (iOS, SwiftUI)

SwiftUI, iOS 17+, Swift 5 language mode, XcodeGen (`project.yml`). No third-party code yet
(Google Sign-In will be added via Swift Package Manager when the account feature is built).

## Layout
```
App/
  IlmApp.swift            @main (+ AppDelegate: notification delegate), RootView (onboarding gate, appearance,
                          foreground hooks), MainTabView (3 tabs, notification taps), AppNav, Route (CI launch args)
  Theme/                  Theme.swift (palette = the site's tokens, AppFont × TextScale, Appearance, Num), BrandMark.swift
  Packs/                  PackStore (bundled `packs/` folder + downloaded versions), PackSync (updates), Models (contract mirror)
  Features/
    Onboarding/           notifications-only first launch
    Home/                 the two treasures
    Names/                mirror of the website's names pages (see below)
    Sunan/                mirror of the website's /sunan pages
    Reminder/             MorningReminder (rolling window, NotificationText, NotificationRouter), ReminderProbe (CI only)
    Saved/                «محفوظاتي»: explains that saving needs the account (no local saving — owner's rule)
    More/                 «المزيد» settings + MarkdownPageView (about / methodology from the names pack `pages`)
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
- Sync (`PackSync`, after the first frame of a launch, again on return after 12 h, and «تحقّق من التحديث» in «المزيد»;
  never in CI): GET `/api/app/v1/manifest` (exact URL, no query); for each section whose version differs from the
  current one (active download, else bundled) and whose `schema` ≤ 1, `PackDownloader` downloads every listed file from
  `/api/app/v1/packs/<section>/<version>/<file>` into a temp dir (4 at a time), checks byte size + sha256 (CryptoKit),
  decodes the index (version, chunk/extras files present), then moves the folder to
  Application Support/packs/<section>/<version>/ and marks it `packs.ready.<section>`.
  Activation (`activateReady`): `packs.active.<section>` = version, PackStore cache cleared, `NamesRepo`/`SunanRepo`
  rebuilt, `NameDetails`/`SunanStore` caches reset, older downloads deleted, `contentVersion` bumped (Home and «المزيد»
  observe it), reminders rescheduled. It waits while a page of that section is in the «الرئيسية» stack (ids such as
  domain/need/state change between versions); from «المزيد» it goes back out of those pages and applies at once.
  `PackStore.prepareAtLaunch()` (App init) applies a waiting version, and drops downloads when the bundled snapshot
  changed (new app build). The active download is used for the whole section, never mixed with bundled files.
  Any failure keeps the current version.

## Names section = the website
Screens map 1:1 to the site's routes and reuse its wording and order:
`/` (names home) → `/feel` (16 doors) → `/feel/<door>` → `/feel/<door>/<situation>` → `/feel/<door>/<situation>/<id>`
(the name inside the situation) · `/names` (all names) · `/names/<id>` (tabs: الآيات · في السنة · ماذا يعلّمني ·
متى أستحضره · متى أدعو به · الزبدة) · `/feel/anfus` · `/ask` (POST `/api/ask/instant`).

## Sunan section = the website
`App/Features/Sunan/*` mirrors `app/sunan/**` (wording from `lib/sunan/view.ts` and `components/sunan/*`):
`/sunan` (`SunanHomeView`: header + search, «برنامج اليوم والليلة», «ماذا يجلب هذا العمل؟», 12 domains, «وفي الأصول»)
→ `/sunan/<domain>` (ما تعمله · ما تتجنّبه) → `/sunan/<domain>/<need>` (states) → `/sunan/<domain>/<need>/<state>`
(representatives, «ابدأ بهذه» first) → `/sunan/item/<fp>` (easy line, طريقة التطبيق, full text with cause/result runs,
folds, بمعناها, مداخل أخرى) · `/sunan/search` · `/sunan/macro` · `/sunan/pairs` · `/sunan/method` · `/sunan/day` (3 main categories) → category (its times, app only) → `/sunan/day/<time>`
· `/sunan/deeds[/<deed>]`. Routes: `SunanRoute` (`HomeDestination.s`). Data: `SunanRepo` (index, lookups, state search)
and the `SunanStore` actor (chunks, item by fp — state hint, then «ابدأ بهذه», then a lazily built fp → chunk map —,
day.json, deeds.json), all decoded off the main thread and cached.

## Daily logic (must match the site)
- name of day: `utcDay = floor(epochMs / 86_400_000)`; `sequential_by_date` → `names[utcDay % names.count]`.
- morning notification (`MorningReminder`): rolling 30 local notifications at the chosen time (default 07:00,
  `reminder.hour/minute`, off with `reminder.enabled`), ids `morning-YYYY-MM-DD`; the name is `nameOfDay(fireDate)`;
  title «اسم اليوم: <name>», body = the card's `excerpt` cut to ≤ 140 scalars by `NotificationText` (never inside an
  ayah: cut before «﴿» or keep the whole ayah), userInfo `{route: "name", nameId}`. Rescheduled on launch / foreground,
  after onboarding, on time or switch change, and after a names update. Taps (cold start too) → `NotificationRouter`
  → `AppNav.openName` → «الرئيسية» › names › the name page.

## Settings («المزيد»)
- appearance `appearance` = system | dark (default) | light → `preferredColorScheme` + the windows' style.
- text size `textScale` = 0 | 1 | 2 (×1, ×1.15, ×1.3) → `TextScale` (@Observable) multiplies every `AppFont` size,
  on top of Dynamic Type.
- content status (versions as dates in Arabic, bundled / downloaded, last check), feedback → the site's `/suggest`,
  «الحساب — قريبًا» placeholder, version line.

- widgets (owner 2026-11-26): «أداة الشاشة الرئيسية» (`widget.collection`) takes "" (تلقائي) | `@name` | `@sunnah` |
  a collection's id. `WidgetShare` describes it as a `WidgetSetup` in the shared keychain group; the extension's
  `TodayEntry.make` draws it. The small lock screen widget (accessory families) was removed on 2026-11-27 (owner: its
  box is too small) — the lock screen has the wide card below only. An app cannot add or remove a widget — the reader does.
- «العرض الكبير على شاشة القفل» (`live.enabled`, on by default; the first card starts right after onboarding): a Live Activity — the only wide thing iOS allows on
  the lock screen. `LiveToday` starts the day's sunnah card when the app comes to the front (once a day; iOS starts
  one only from the foreground or by a server push, keeps it ~8 h active + 4 h on the lock screen); «تمّت»
  (`TodayDoneIntent`, runs in the app) ends it. Attributes, intent and the card view: `Shared/TodayActivity.swift`;
  the configuration and Dynamic Island: `Widgets/IlmLiveActivity.swift`; `NSSupportsLiveActivities` in project.yml.
  Not built yet: the morning start by a server push (needs the Push Notifications capability, an APNs key on the
  platform, and the push-to-start token sent to it).

## CI routes (ci/routes.txt `name|args[|wait]`)
`more`, `moreupdate` (presses «تحقّق من التحديث»), `morebottom`, `moreabout`; `-appearance light`, `-textScale 2`;
`notif` / `notiftap` with `-ciNotify YES` (provisional permission, schedules the real window; overlay of the pending
ones + a live banner / opens what a tap on the first one opens).
