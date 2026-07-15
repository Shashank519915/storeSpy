"""Read edge-flags.yaml (simple key: value parser)."""

from __future__ import annotations

from pathlib import Path


def load_edge_flags(path: str | Path | None = None) -> dict[str, str | int | float | bool]:
    if path is None:
        path = Path(__file__).resolve().parents[4] / "infra/config/dev/edge-flags.yaml"
    path = Path(path)
    flags: dict[str, str | int | float | bool] = {}
    if not path.exists():
        return flags
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if ":" not in stripped:
            continue
        key, raw = stripped.split(":", 1)
        key = key.strip()
        raw = raw.split("#", 1)[0].strip()
        if raw.lower() in ("true", "false"):
            flags[key] = raw.lower() == "true"
        elif raw.isdigit():
            flags[key] = int(raw)
        else:
            try:
                flags[key] = float(raw)
            except ValueError:
                flags[key] = raw.strip('"').strip("'")
    return flags
