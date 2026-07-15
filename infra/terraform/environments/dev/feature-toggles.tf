# Feature toggles — flip in HCP Terraform workspace variables OR edit defaults here.
# See docs/runbooks/feature-toggles.md

variable "enable_msk" {
  type        = bool
  default     = false
  description = "AWS MSK cluster (3× kafka.t3.small). Off until account MSK subscription is active."
}

variable "enable_rds" {
  type        = bool
  default     = true
  description = "RDS PostgreSQL 16 (db.t4g.micro, single-AZ dev)."
}

# Helm / runtime toggles (documented for deploy scripts — not Terraform resources)
variable "enable_incluster_kafka" {
  type        = bool
  default     = false
  description = "Deploy single-broker Kafka on EKS when MSK is off (Debezium dev path). Helm: infra/helm/charts/kafka-dev/"
}

variable "enable_schema_registry" {
  type        = bool
  default     = false
  description = "Deploy Schema Registry on EKS. Requires Kafka (MSK or in-cluster)."
}

variable "enable_debezium" {
  type        = bool
  default     = false
  description = "Deploy Kafka Connect + Debezium on EKS. Requires Kafka + RDS."
}

locals {
  feature_flags = {
    enable_msk             = var.enable_msk
    enable_rds             = var.enable_rds
    enable_incluster_kafka = var.enable_incluster_kafka
    enable_schema_registry = var.enable_schema_registry
    enable_debezium        = var.enable_debezium
  }

  # Kafka bootstrap for Helm / apps — MSK takes precedence when enabled
  kafka_bootstrap_servers = var.enable_msk ? (
    length(module.msk) > 0 ? module.msk[0].bootstrap_brokers_sasl_iam : ""
    ) : (
    var.enable_incluster_kafka ? "kafka-dev.rip-system.svc.cluster.local:9092" : ""
  )

  kafka_auth_mode = var.enable_msk ? "aws_msk_iam" : "plaintext"
}
