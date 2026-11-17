/** Content packs are Metro assets (see metro.config.js): `require()` returns an asset module id. */
declare module "*.pack" {
  const assetModule: number;
  export default assetModule;
}

declare module "*.otf" {
  const assetModule: number;
  export default assetModule;
}

declare module "*.ttf" {
  const assetModule: number;
  export default assetModule;
}
