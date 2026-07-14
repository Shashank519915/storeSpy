import config from "@rip/eslint-config";

export default [
  ...config,
  {
    ignores: ["dist/**"],
  },
];
