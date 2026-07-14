variable "name" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "cluster_oidc_provider_arn" {
  type = string
}

variable "vault_namespace" {
  type    = string
  default = "rip-system"
}

variable "vault_service_account" {
  type    = string
  default = "vault"
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  oidc_provider_host = replace(var.cluster_oidc_issuer_url, "https://", "")
  vault_audit_bucket = "rip-vault-audit-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vault_unseal" {
  description             = "Vault auto-unseal for ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name    = "${var.name}-vault-unseal"
    Purpose = "vault-auto-unseal"
  })
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/rip-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_s3_bucket" "vault_audit" {
  bucket = local.vault_audit_bucket

  tags = merge(var.tags, {
    Name    = local.vault_audit_bucket
    Purpose = "vault-audit"
  })
}

resource "aws_s3_bucket_versioning" "vault_audit" {
  bucket = aws_s3_bucket.vault_audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vault_audit" {
  bucket = aws_s3_bucket.vault_audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "vault_audit" {
  bucket = aws_s3_bucket.vault_audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "vault" {
  name = "${var.name}-vault"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.cluster_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:${var.vault_namespace}:${var.vault_service_account}"
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vault" {
  name = "${var.name}-vault-kms-s3"
  role = aws_iam_role.vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSUnseal"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault_unseal.arn
      },
      {
        Sid    = "VaultAuditS3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vault_audit.arn,
          "${aws_s3_bucket.vault_audit.arn}/*"
        ]
      }
    ]
  })
}

output "kms_key_arn" {
  value = aws_kms_key.vault_unseal.arn
}

output "kms_key_alias" {
  value = aws_kms_alias.vault_unseal.name
}

output "vault_audit_bucket" {
  value = aws_s3_bucket.vault_audit.id
}

output "vault_irsa_role_arn" {
  value = aws_iam_role.vault.arn
}
