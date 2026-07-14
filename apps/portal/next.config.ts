import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@rip/ui"],
  typedRoutes: true,
};

export default nextConfig;
