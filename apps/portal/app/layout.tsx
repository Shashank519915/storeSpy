import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RIP — Retail Intelligence Platform",
  description: "Enterprise operations command center",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" data-density="compact" suppressHydrationWarning>
      <body>
        <a href="#main-content" className="skip-link">
          Skip to main content
        </a>
        {children}
      </body>
    </html>
  );
}
