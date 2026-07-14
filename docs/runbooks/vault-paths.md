# Vault Path Convention — RIP

**Authority:** `code_style.md` §2.3

## Path Structure

```
secret/data/rip/<env>/<service>/<key>
```

| Segment | Values | Example |
|---------|--------|---------|
| `env` | `dev`, `staging`, `prod` | `dev` |
| `service` | K8s deployment name | `api-gateway` |
| `key` | Credential identifier | `db-password` |

## Namespaces (Vault Enterprise / OSS paths)

| Namespace | Purpose |
|-----------|---------|
| `rip/dev` | Development secrets |
| `rip/staging` | Staging secrets |
| `rip/prod` | Production secrets |

## PKI Paths

| Path | Purpose | TTL |
|------|---------|-----|
| `pki_int/issue/rip-internal-ca` | Service mTLS certs | 24h |
| `pki_int/cert/ca` | Intermediate CA chain | — |

## Database Dynamic Credentials

| Path | Engine | TTL |
|------|--------|-----|
| `database/creds/rip-postgresql` | PostgreSQL | 1h |

## WireGuard Peer Keys

```
secret/data/rip/<env>/wireguard/peers/<store_id>
```

Fields: `public_key`, `private_key` (edge only), `allowed_ips`, `endpoint`

## Kubernetes Auth Roles

| Role | Bound SA | Policies |
|------|----------|----------|
| `api-gateway` | `rip-system/api-gateway` | `rip-api-gateway` |
| `portal` | `rip-system/portal` | `rip-portal-readonly` |
| `edge-bridge` | `rip-edge/edge-bridge` | `rip-edge-bridge` |

## Forbidden

- Hardcoded secrets in manifests or source code
- Committed join tokens for SPIRE
- Long-lived AWS access keys (use OIDC + IRSA)

## Rotation

| Secret Type | Rotation | Owner |
|-------------|----------|-------|
| Service certs (PKI) | Auto 24h | Vault PKI engine |
| DB dynamic creds | Auto 1h | Vault Database engine |
| WireGuard keys | Manual 90d | SRE |
| JWT signing keys | Manual 180d | Security |
