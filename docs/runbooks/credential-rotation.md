# Credential & Key Rotation — rip-dev

Precise rotation steps for secrets used in Phase 0/1. Run from **repo root** in PowerShell unless noted.

**Prerequisites:** `aws`, `kubectl`, `helm` configured for account `406193643001`, region `us-east-1`, cluster `rip-dev`.

---

## Quick reference

| Secret | Where stored | Rotation cadence | Auto-rotates? |
|--------|--------------|------------------|---------------|
| AWS IAM access keys (local CLI) | `~/.aws/credentials` | 90d or on exposure | No |
| RDS master password | Secrets Manager `rip-dev/rds/postgres` | 90d or on exposure | No |
| PgBouncer admin/userlist | Helm values + SM password | When RDS rotates | No |
| Vault root token | Offline only (`vault-init.json` never committed) | On exposure; prefer limited policies | No |
| Vault recovery keys | Offline only | On exposure | No |
| Vault dynamic DB creds | `database/creds/rip-postgresql*` | 1h TTL | Yes |
| Vault PKI service certs | `pki_int/issue/rip-internal-ca` | 24h | Yes |
| K8s SA tokens (Vault auth) | Auto-mounted in pods | Short-lived | Yes |
| `BUF_TOKEN` (GitHub secret) | GitHub repo secrets | 180d | No |

---

## 1. AWS IAM access keys (local developer CLI)

Use when keys were exposed (terminal logs, chat, screenshots) or per security policy.

### 1a. Create a new key for your IAM user

```powershell
# List your IAM username
aws sts get-caller-identity

# Create new access key (max 2 per user — delete old one after verifying new key)
aws iam create-access-key --user-name <YOUR_IAM_USER>
```

### 1b. Configure AWS CLI with the new key

```powershell
aws configure
# Enter new Access Key ID, Secret Access Key, region us-east-1, output json
```

### 1c. Verify and delete the old key

```powershell
aws sts get-caller-identity
aws eks update-kubeconfig --region us-east-1 --name rip-dev
kubectl get nodes

# Delete compromised key (use KeyId from iam list-access-keys)
aws iam list-access-keys --user-name <YOUR_IAM_USER>
aws iam delete-access-key --user-name <YOUR_IAM_USER> --access-key-id <OLD_KEY_ID>
```

**Preferred long-term:** use AWS SSO or IAM Identity Center instead of long-lived access keys.

---

## 2. RDS PostgreSQL master password (`rip_admin`)

RDS is **private** (`publicly_accessible = false`). Master creds live in Secrets Manager `rip-dev/rds/postgres`.

### 2a. Generate and apply a new password

```powershell
# Generate a strong password (32 chars, no special chars — matches Terraform random_password style)
$newPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
$newPassword  # copy temporarily to a password manager — do not commit

aws rds modify-db-instance `
  --region us-east-1 `
  --db-instance-identifier rip-dev-postgres `
  --master-user-password $newPassword `
  --apply-immediately
```

Wait until status is `available`:

```powershell
aws rds describe-db-instances `
  --db-instance-identifier rip-dev-postgres `
  --query "DBInstances[0].DBInstanceStatus" `
  --output text
```

### 2b. Update Secrets Manager

```powershell
$secret = aws secretsmanager get-secret-value `
  --secret-id rip-dev/rds/postgres `
  --query SecretString --output text | ConvertFrom-Json

$secret.password = $newPassword
$secret | ConvertTo-Json -Compress | Set-Content -Encoding utf8 .tmp-rds-secret.json

aws secretsmanager put-secret-value `
  --secret-id rip-dev/rds/postgres `
  --secret-string file://.tmp-rds-secret.json

Remove-Item .tmp-rds-secret.json -Force
```

### 2c. Redeploy PgBouncer with the new password

```powershell
$RdsEndpoint = aws rds describe-db-instances `
  --region us-east-1 `
  --db-instance-identifier rip-dev-postgres `
  --query "DBInstances[0].Endpoint.Address" `
  --output text

helm upgrade --install pgbouncer icoretech/pgbouncer -n rip-system `
  -f infra/helm/charts/pgbouncer/values.yaml `
  -f infra/helm/charts/pgbouncer/values-dev.yaml `
  --set "config.databases.rip.host=$RdsEndpoint" `
  --set "config.adminPassword=$newPassword" `
  --set-string "config.userlist.rip_admin=$newPassword" `
  --wait --timeout 5m
```

### 2d. Update Vault database engine connection

```powershell
# Requires root token — store offline, never commit
$RootToken = Read-Host "Vault root token"
$secret = aws secretsmanager get-secret-value --secret-id rip-dev/rds/postgres --query SecretString --output text | ConvertFrom-Json
$connUrl = "postgresql://$($secret.username):$($secret.password)@$($secret.host):$($secret.port)/$($secret.database)?sslmode=require"

kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$RootToken vault write database/config/rip-postgresql connection_url='$connUrl'"
```

### 2e. Verify connectivity

```powershell
# Terminal 1
kubectl port-forward svc/pgbouncer -n rip-system 15432:5432

# Terminal 2
$env:Path = "C:\Program Files\PostgreSQL\17\bin;" + $env:Path
$env:PGPORT = "15432"
$env:PGPASSWORD = $newPassword
psql -h localhost -U rip_admin -d rip -c "SELECT 1;"
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
```

---

## 3. Vault root token

**Never store in git, chat, or CI.** Keep only in an offline password manager.

### 3a. If token is exposed — revoke and create a new one

```powershell
$OldToken = Read-Host "Compromised root token"
$NewToken = kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$OldToken vault token create -policy=root -format=json" `
  | ConvertFrom-Json | Select-Object -ExpandProperty auth | Select-Object -ExpandProperty client_token

Write-Host "New root token created — save offline and revoke old token."
# Revoke old token
kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$NewToken vault token revoke $OldToken"
```

### 3b. Prefer limited tokens for day-to-day ops

```powershell
$RootToken = Read-Host "Vault root token"
kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$RootToken vault token create -policy=rip-twin-api -ttl=8h"
```

Use limited tokens in scripts instead of root where possible.

### 3c. Recovery keys (disaster)

Recovery keys from `vault operator init` are required if KMS auto-unseal fails. Stored offline at init time (`vault-init.json` — delete from disk after copying keys to a vault).

```powershell
# Re-key (advanced — requires quorum of recovery keys)
kubectl exec -n rip-system vault-0 -- vault operator rekey -init -key-shares=5 -key-threshold=3
```

Auto-unseal uses KMS key `alias/rip-vault-unseal` (Terraform `vault-prerequisites` module).

---

## 4. Vault dynamic database credentials

Configured by `scripts/vault-database-bootstrap.ps1`. **No manual rotation** — Vault issues short-lived creds.

| Path | TTL | Used by |
|------|-----|---------|
| `database/creds/rip-postgresql` | 1h | Full app access |
| `database/creds/rip-postgresql-twin` | 1h | `twin-api` (twin schema only) |

### Issue a test credential (verify engine health)

```powershell
$RootToken = Read-Host "Vault root token"
kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$RootToken vault read database/creds/rip-postgresql"
```

### Revoke a leaked dynamic credential immediately

```powershell
kubectl exec -n rip-system vault-0 -- sh -c `
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$RootToken vault lease revoke database/creds/rip-postgresql/<lease-id>"
```

---

## 5. PgBouncer credentials

PgBouncer reads `rip_admin` password from Helm `--set-string config.userlist.rip_admin=...` at deploy time. It does **not** auto-sync when Secrets Manager changes.

After any RDS password rotation, repeat **§2c** (Helm upgrade).

Check pod health:

```powershell
kubectl get pods -n rip-system -l app.kubernetes.io/name=pgbouncer
kubectl logs -n rip-system -l app.kubernetes.io/name=pgbouncer --tail=20
```

---

## 6. Kubernetes / EKS credentials

`kubectl` uses AWS IAM via `aws eks update-kubeconfig`. No separate kubeconfig password.

```powershell
aws eks update-kubeconfig --region us-east-1 --name rip-dev
kubectl auth whoami
```

EKS node and pod IAM uses **IRSA** (no static keys in cluster). MSK IAM roles are dormant while `enable_msk=false`.

---

## 7. GitHub / CI secrets

| Secret | Purpose | Rotation |
|--------|---------|----------|
| `BUF_TOKEN` | `buf push` to BSR on proto changes | Regenerate at [buf.build](https://buf.build) → GitHub repo Settings → Secrets |

```powershell
# After updating BUF_TOKEN in GitHub, re-run workflow
gh workflow run schema-registry.yml
gh run list --workflow=schema-registry.yml --limit 3
```

---

## 8. Exposure incident checklist

If credentials appeared in terminal output, chat, or a commit:

1. **AWS IAM keys** — §1 immediately
2. **Vault root token** — §3a immediately
3. **RDS password** — §2 if SM password was exposed
4. **Dynamic Vault DB lease** — §4 revoke if lease output was exposed
5. Delete local copies: `vault-init.json`, `.tmp-rds-secret.json`, shell history if needed
6. Confirm `.gitignore` blocks `vault-init.json` (already listed)

---

## Related docs

- Vault paths: `docs/runbooks/vault-paths.md`
- Phase 1 deploy: `docs/runbooks/phase-1-live-deployment.md`
- Feature toggles: `docs/runbooks/feature-toggles.md`
