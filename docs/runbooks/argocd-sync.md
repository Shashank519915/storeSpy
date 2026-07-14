# ArgoCD Sync Runbook

## ApplicationSets

| Set | Sync Wave | Contents |
|-----|-----------|----------|
| `rip-infra` | 0–1 | Vault, network-policies, otel-collector |
| `rip-apps` | 2 | `apps/*` services |

## Sync Policy

- Automated sync with prune + selfHeal enabled
- Drift detection active on all Applications
- Manual sync required for prod (Phase 6 hardening)

## Verification

```bash
argocd app list
argocd app get otel-collector
argocd app sync otel-collector
```

## Pass Criteria

- Manifest change syncs within 3 min
- No OutOfSync resources after reconcile
- `otel-collector` DaemonSet healthy in `rip-system`

## Troubleshooting

| Symptom | Action |
|---------|--------|
| Sync failed | `argocd app logs <app> --container=repo-server` |
| Image pull error | Verify ECR tag is not `latest` (Conftest policy) |
| Vault auth failure | Check `ClusterSecretStore` and K8s auth role |
