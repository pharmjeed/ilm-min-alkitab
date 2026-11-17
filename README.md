# علم من الكتاب — app

Expo SDK 58 app (iOS / Android / web) for the content of «منصة أسماء الله الحسنى» and «السنن والأسباب».
Read `CLAUDE.md` and `ARCHITECTURE.md` first.

## Commands

```bash
npm install
npm run web            # dev server in the browser (expo start --web)
npm start              # dev server for Expo Go (scan the QR code)
npm run typecheck      # tsc --noEmit
npm run lint           # expo lint
npm test               # vitest (pure TS in src/lib/**)
npm run packs:bundle   # regenerate src/lib/packs/bundled.ts from assets/packs/<section>/*.pack
npm run export:web     # static web build into dist/
```

Content packs are produced by the platform (`../New folder`):
`npm run app:packs -- names --app ../ilm-min-alkitab` and `npm run app:packs -- sunan --app ../ilm-min-alkitab`,
then `npm run packs:bundle` here.

Node: Expo SDK 58 supports Node 22.13+, 24.3+ or 26+. The commands above were verified on Node 25.9
as well (engine warnings only). If the Expo CLI ever refuses to run on an odd Node release, run it with a
portable Node 24 without touching the system install, e.g.
`npx -y -p node@24 node node_modules/expo/bin/cli start --web`.
