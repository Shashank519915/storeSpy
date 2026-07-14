variable "name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_uuid" {
  type = string
}

variable "cluster_oidc_provider_arn" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "namespace" {
  type    = string
  default = "rip-system"
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  oidc_provider_host = replace(var.cluster_oidc_issuer_url, "https://", "")
  cluster_resource   = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}/${var.cluster_uuid}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "msk_admin" {
  name = "${var.name}-msk-admin"

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
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:${var.namespace}:msk-admin"
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "msk_admin" {
  name = "${var.name}-msk-admin"
  role = aws_iam_role.msk_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MSKClusterConnect"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = local.cluster_resource
      },
      {
        Sid    = "MSKTopicAdmin"
        Effect = "Allow"
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:DeleteTopic",
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopicDynamicConfiguration",
          "kafka-cluster:AlterTopicDynamicConfiguration"
        ]
        Resource = "${local.cluster_resource}/*"
      },
      {
        Sid    = "MSKGroupAdmin"
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "${local.cluster_resource}/*"
      }
    ]
  })
}

resource "aws_iam_role" "msk_producer" {
  name = "${var.name}-msk-producer"

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
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${local.oidc_provider_host}:sub" = [
            "system:serviceaccount:${var.namespace}:event-injector",
            "system:serviceaccount:${var.namespace}:edge-bridge"
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "msk_producer" {
  name = "${var.name}-msk-producer"
  role = aws_iam_role.msk_producer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MSKConnect"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = local.cluster_resource
      },
      {
        Sid    = "MSKWriteDomainTopics"
        Effect = "Allow"
        Action = [
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic"
        ]
        Resource = [
          "${local.cluster_resource}/vision.interaction.*",
          "${local.cluster_resource}/vision.tracking.*",
          "${local.cluster_resource}/twin.mutations.*",
          "${local.cluster_resource}/retail.pos.*",
          "${local.cluster_resource}/lp.engine.*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "msk_consumer" {
  name = "${var.name}-msk-consumer"

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
          "${local.oidc_provider_host}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:rip-*:*"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "msk_consumer" {
  name = "${var.name}-msk-consumer"
  role = aws_iam_role.msk_consumer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MSKConnect"
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = local.cluster_resource
      },
      {
        Sid    = "MSKReadWriteConsumerTopics"
        Effect = "Allow"
        Action = [
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "${local.cluster_resource}/*"
      }
    ]
  })
}

output "msk_admin_role_arn" {
  value = aws_iam_role.msk_admin.arn
}

output "msk_producer_role_arn" {
  value = aws_iam_role.msk_producer.arn
}

output "msk_consumer_role_arn" {
  value = aws_iam_role.msk_consumer.arn
}
