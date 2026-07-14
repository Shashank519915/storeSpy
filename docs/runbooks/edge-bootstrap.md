# Edge Bootstrap Runbook

## Prerequisites

- NVIDIA IGX or RTX node with Ubuntu 22.04
- SSH access with sudo
- `K3S_TOKEN` env var (from Vault, never committed)

## Steps

1. **Inventory:** Add node to `infra/ansible/inventory/edge.ini`
2. **Bootstrap:** `ansible-playbook -i inventory/edge.ini edge-bootstrap.yml`
3. **K3s:** `K3S_TOKEN=<from-vault> ansible-playbook -i inventory/edge.ini k3s-install.yml`
4. **GPU Operator:** `kubectl apply -f edge/gpu-operator/`
5. **Verify GPU:** `kubectl describe node | grep nvidia.com/gpu`
6. **DCGM:** Confirm `DCGM_FI_DEV_GPU_UTIL` in Prometheus within 60s

## Pass Criteria

- Node Ready < 5 min after K3s install
- `nvidia.com/gpu: 1` allocatable
- DCGM metrics visible in Grafana
