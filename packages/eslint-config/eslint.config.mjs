import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import { ripPlugin } from "./src/rip-plugin.mjs";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.browser,
      },
    },
    plugins: {
      rip: ripPlugin,
    },
    rules: {
      "rip/no-raw-color": "error",
    },
  },
  {
    ignores: ["**/dist/**", "**/.next/**", "**/node_modules/**", "**/gen/**"],
  }
);
