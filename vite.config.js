import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

export default defineConfig(({ mode }) => ({
  plugins: [elmPlugin({ debug: mode === "development" })],
  base: mode === "production" ? "/rr-elm-5/" : "/",
  build: {
    minify: "terser",
    terserOptions: {
      compress: {
        pure_funcs: ["F2","F3","F4","F5","F6","F7","F8","F9","A2","A3","A4","A5","A6","A7","A8","A9"],
        pure_getters: true,
        keep_fargs: false,
        unsafe_comps: true,
        unsafe: true
      },
      mangle: true
    }
  }
}));
