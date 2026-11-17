// Learn more: https://docs.expo.dev/guides/customizing-metro/
const { getDefaultConfig } = require("expo/metro-config");

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

// Content packs (assets/packs/<section>/*.pack) are JSON files bundled as ASSETS (not source) so they
// are not inlined into the JS bundle; they are read at runtime (see src/lib/packs/reader*.ts).
// Never add "json" here: it is a source extension.
if (!config.resolver.assetExts.includes("pack")) {
  config.resolver.assetExts.push("pack");
}

module.exports = config;
