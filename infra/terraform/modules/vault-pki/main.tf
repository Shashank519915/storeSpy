# Vault PKI — intermediate CA rip-internal-ca
# Applied via Terraform Vault provider after Vault HA bootstrap

variable "vault_address" {
  type = string
}

variable "pki_path" {
  type    = string
  default = "pki_int"
}

variable "common_name" {
  type    = string
  default = "rip-internal-ca"
}

variable "ttl" {
  type    = string
  default = "8760h"
}

variable "service_cert_ttl" {
  type    = string
  default = "24h"
}

# Terraform Vault provider configuration applied at deploy time.
# See infra/helm/charts/vault/ for HA cluster bootstrap first.

output "pki_mount_path" {
  value = var.pki_path
}

output "service_cert_ttl" {
  value = var.service_cert_ttl
}
