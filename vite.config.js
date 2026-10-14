import { defineConfig } from "vite";

// Compile JSX to mini-react's createElement / Fragment (jsx.js).
const jsx = {
  runtime: "classic",
  pragma: "createElement",
  pragmaFrag: "Fragment",
  // Otherwise dev builds add __self / __source props, which jsx.js would
  // turn into DOM properties.
  development: false,
};

// Apart from the JSX settings, every value here is the Vite 8 default, written
// out explicitly so the build is declared rather than inherited.
export default defineConfig({
  root: ".",
  base: "/",
  publicDir: "public",
  cacheDir: "node_modules/.vite",
  appType: "spa",

  resolve: {
    preserveSymlinks: false,
  },

  oxc: { jsx },

  // The dependency scanner does not read `oxc`; without this it looks for
  // react/jsx-dev-runtime.
  optimizeDeps: {
    rolldownOptions: { transform: { jsx } },
  },

  build: {
    target: "baseline-widely-available",
    outDir: "dist",
    assetsDir: "assets",
    assetsInlineLimit: 4096,
    cssCodeSplit: true,
    cssMinify: "lightningcss",
    minify: "oxc",
    sourcemap: false,
    emptyOutDir: true,
    copyPublicDir: true,
    modulePreload: { polyfill: true },
    reportCompressedSize: true,
    chunkSizeWarningLimit: 500,
  },

  server: {
    host: "localhost",
    port: 5173,
    strictPort: false,
  },

  preview: {
    port: 4173,
  },
});
