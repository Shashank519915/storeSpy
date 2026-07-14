# ADR 0001: Turborepo + Nx Dual Orchestration

**Status:** Accepted  
**Date:** 2026-07-14  
**Deciders:** Platform Engineering

## Context

RIP is a polyglot monorepo spanning Go, Python, TypeScript, Rust, Terraform, and Helm. We need:

1. Fast incremental builds with remote caching for JS/TS packages
2. A project graph that understands cross-language dependencies
3. CI that runs only affected packages on PRs

## Decision

Use **Turborepo** as the primary task runner for JavaScript/TypeScript packages and **Nx** as the project graph / affected-analysis layer.

| Tool | Responsibility |
|------|----------------|
| Turborepo | `build`, `lint`, `test`, `dev` task orchestration with content-addressable cache |
| Nx | Project graph, `namedInputs` per language (go, python, typescript, terraform, helm) |
| pnpm | Workspace dependency resolution, catalogs, frozen lockfile in CI |

## Rationale

- Turborepo excels at JS/TS pipeline caching (`dependsOn: ["^build"]`) with minimal config
- Nx provides language-aware input hashing without forcing Nx executors on Go/Python services
- Dual orchestration is documented in Turborepo + Nx integration patterns for enterprise monorepos
- `pnpm` workspaces enforce strict dependency boundaries per `code_style.md` §2.4

## Consequences

### Positive
- Portal and `packages/ui` builds cache aggressively
- `nx affected` can gate CI matrix expansion in later phases
- Single `pnpm-lock.yaml` for all TS dependencies

### Negative
- Two config files (`turbo.json`, `nx.json`) must stay synchronized
- Go/Python services use package-level scripts invoked via Turborepo filters, not Nx executors

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Nx only | Heavier config for pure Turborepo-style JS caching |
| Turborepo only | Weaker polyglot project graph without Nx `namedInputs` |
| Bazel | Operational overhead disproportionate for team size at Phase 0 |

## Compliance

- `turbo.json` defines task DAG
- `nx.json` defines `namedInputs` for go, python, typescript, terraform, helm
- CI runs `pnpm turbo run lint` with `--filter` for affected packages
