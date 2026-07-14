# Network CIDR Planning — RIP

## Cloud VPC (dev)

| CIDR | Purpose |
|------|---------|
| `10.0.0.0/16` | Cloud VPC (EKS, MSK, RDS) |
| `10.0.0.0/24` – `10.0.2.0/24` | Public subnets (NAT, ALB) |
| `10.0.10.0/24` – `10.0.12.0/24` | Private subnets (EKS nodes) |
| `10.0.20.0/24` – `10.0.22.0/24` | Database subnets (RDS, ElastiCache) |

## WireGuard tunnel (edge → cloud)

| CIDR | Purpose |
|------|---------|
| `10.200.0.0/16` | Cloud services reachable via tunnel |
| `10.201.0.0/24` | Edge store LAN (per-store /24) |

## Kubernetes service CIDR

| CIDR | Purpose |
|------|---------|
| `172.20.0.0/16` | EKS service CIDR |
| `10.96.0.0/12` | K3s default service CIDR (edge) |

## Rules

- No overlapping CIDRs between cloud VPC and edge stores
- MSK brokers reachable only via WireGuard peer SG rules
- Document any CIDR change via ADR before apply
