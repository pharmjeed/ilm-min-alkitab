import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// Pure TS tests only (src/lib/**): these modules must not import react-native / expo.
export default defineConfig({
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  test: {
    include: ["src/lib/**/*.test.ts", "scripts/**/*.test.ts"],
    environment: "node",
  },
});
