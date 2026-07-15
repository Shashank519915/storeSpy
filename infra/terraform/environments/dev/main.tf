# RIP Dev Environment
# Terraform Cloud workspaces: rip-dev, rip-staging, rip-prod
# Remote state locking via Terraform Cloud

terraform {
  required_version = ">= 1.9.0"

  cloud {
    organization = "rip-platform"

    workspaces {
      name = "rip-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "github_org" {
  type    = string
  default = "Shashank519915"
}

variable "github_repo" {
  type    = string
  default = "storeSpy"
}

locals {
  name = "rip-${var.environment}"

  common_tags = {
    Project     = "rip"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # CIDR planning — see docs/runbooks/network-cidr.md
  vpc_cidr = "10.0.0.0/16"

  # Predictable S3 name — known at plan time (avoids count dependency on module output)
  terraform_state_bucket_arn = "arn:aws:s3:::rip-terraform-state-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

module "s3_foundation" {
  source = "../../modules/s3-foundation"
  name   = local.name
  tags   = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cidr_block           = local.vpc_cidr
  az_count             = 3
  enable_flow_logs     = true
  flow_logs_bucket_arn = local.terraform_state_bucket_arn
  tags                 = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  cluster_version    = "1.31"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  tags               = local.common_tags

  # t3.micro fits Terraform/EKS bootstrap only (4 pods/node). Platform Helm needs t3.small+.
  # Add a payment method in AWS Billing if apply fails on instance type eligibility.
  system_instance_types   = ["t3.small"]
  workload_instance_types = ["t3.small"]
  system_desired_size     = 1
  workload_desired_size   = 1
}

module "security_baseline" {
  source = "../../modules/security-baseline"
  name   = local.name
  tags   = local.common_tags
}

module "iam_github_oidc" {
  source      = "../../modules/iam-github-oidc"
  name        = local.name
  github_org  = var.github_org
  github_repo = var.github_repo
  tags        = local.common_tags
}

module "ecr_repositories" {
  source = "../../modules/ecr-repositories"
  name   = local.name
  tags   = local.common_tags
}

module "vault_prerequisites" {
  source = "../../modules/vault-prerequisites"

  name                      = local.name
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  tags                      = local.common_tags
}

module "msk" {
  count  = var.enable_msk ? 1 : 0
  source = "../../modules/msk"

  name                 = local.name
  vpc_id               = module.vpc.vpc_id
  vpc_cidr             = local.vpc_cidr
  private_subnet_ids   = module.vpc.private_subnet_ids
  broker_instance_type = "kafka.t3.small"
  broker_count         = 3
  tags                 = local.common_tags
}

module "msk_topics" {
  source      = "../../modules/msk-topics"
  environment = var.environment
}

module "msk_iam" {
  count  = var.enable_msk ? 1 : 0
  source = "../../modules/msk-iam"

  name                      = local.name
  cluster_arn               = module.msk[0].cluster_arn
  cluster_name              = module.msk[0].cluster_name
  cluster_uuid              = module.msk[0].cluster_uuid
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  tags                      = local.common_tags
}

module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "../../modules/rds-postgres"

  name                       = local.name
  vpc_id                     = module.vpc.vpc_id
  vpc_cidr                   = local.vpc_cidr
  database_subnet_group_name = module.vpc.database_subnet_group_name
  tags                       = local.common_tags
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ci_deploy_role_arn" {
  value = module.iam_github_oidc.role_arn
}

output "s3_buckets" {
  value = module.s3_foundation.bucket_names
}

output "ecr_repository_urls" {
  value = module.ecr_repositories.repository_urls
}

output "vault_irsa_role_arn" {
  value = module.vault_prerequisites.vault_irsa_role_arn
}

output "vault_kms_key_alias" {
  value = module.vault_prerequisites.kms_key_alias
}

output "msk_cluster_arn" {
  value = var.enable_msk ? module.msk[0].cluster_arn : null
}

output "msk_bootstrap_brokers_sasl_iam" {
  value     = var.enable_msk ? module.msk[0].bootstrap_brokers_sasl_iam : null
  sensitive = true
}

output "msk_topic_manifest" {
  value = module.msk_topics.topics
}

output "msk_admin_role_arn" {
  value = var.enable_msk ? module.msk_iam[0].msk_admin_role_arn : null
}

output "feature_flags" {
  value = local.feature_flags
}

output "kafka_bootstrap_servers" {
  value     = local.kafka_bootstrap_servers != "" ? local.kafka_bootstrap_servers : null
  sensitive = true
}

output "kafka_auth_mode" {
  value = local.kafka_auth_mode
}

output "rds_endpoint" {
  value = var.enable_rds ? module.rds[0].endpoint : null
}

output "rds_port" {
  value = var.enable_rds ? module.rds[0].port : null
}

output "rds_database_name" {
  value = var.enable_rds ? module.rds[0].database_name : null
}

output "rds_master_username" {
  value = var.enable_rds ? module.rds[0].master_username : null
}

output "rds_master_password" {
  value     = var.enable_rds ? module.rds[0].master_password : null
  sensitive = true
}

output "rds_secrets_manager_arn" {
  value = var.enable_rds ? module.rds[0].secrets_manager_arn : null
}
