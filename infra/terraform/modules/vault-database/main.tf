# Vault Database Secrets Engine — PostgreSQL dynamic credentials (1h TTL)

variable "vault_address" {
  type = string
}

variable "database_path" {
  type    = string
  default = "database"
}

variable "postgresql_host" {
  type = string
}

variable "credential_ttl" {
  type    = string
  default = "1h"
}

output "credential_path" {
  value = "${var.database_path}/creds/rip-postgresql"
}

output "credential_ttl" {
  value = var.credential_ttl
}
