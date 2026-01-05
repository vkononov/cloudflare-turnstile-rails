import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "script",
      globals: {
        ...globals.browser,
        turnstile: 'readonly',
        Turbolinks: 'readonly',
      },
    },
    rules: {
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-console": "warn",
      semi: ["error", "always"],
      quotes: ["error", "single", { avoidEscape: true }],
    },
  },
  {
    ignores: [
      "eslint.config.js",
      "node_modules/",
      "vendor/",
      "tmp/",
      "test/generators/tmp/",
      "templates/shared/app/views/**/*.erb",
    ],
  },
];

