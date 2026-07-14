import nextConfig from "@rip/eslint-config/next";

export default [
  ...nextConfig,
  {
    ignores: [".next/**", "next-env.d.ts"],
  },
];
