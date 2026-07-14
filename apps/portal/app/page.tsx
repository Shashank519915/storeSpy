export default function HomePage() {
  return (
    <main
      id="main-content"
      className="flex min-h-screen flex-col items-center justify-center gap-4 bg-background p-rip-4"
    >
      <h1 className="text-balance text-xl font-semibold tracking-xl text-foreground">
        Retail Intelligence Platform
      </h1>
      <p className="max-w-prose text-pretty text-sm text-muted-foreground">
        Phase 0 foundation scaffold. Design tokens wired via OKLCH CSS variables.
      </p>
      <div className="flex gap-2">
        <span className="inline-flex items-center gap-2 rounded-md border border-border px-3 py-1.5 text-xs tabular-nums">
          <span
            className="size-2 rounded-full"
            style={{ backgroundColor: "var(--rip-camera-online)" }}
            aria-hidden="true"
          />
          Camera online token
        </span>
        <span className="inline-flex items-center gap-2 rounded-md border border-border px-3 py-1.5 text-xs tabular-nums">
          <span
            className="size-2 rounded-full"
            style={{ backgroundColor: "var(--rip-theft-score-high)" }}
            aria-hidden="true"
          />
          Theft score token
        </span>
      </div>
    </main>
  );
}
