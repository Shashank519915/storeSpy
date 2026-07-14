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
}

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
  flow_logs_bucket_arn = module.s3_foundation.terraform_state_bucket_arn
  tags                 = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  cluster_version    = "1.29"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  tags               = local.common_tags
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
