variable "name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  buckets = {
    terraform_state = {
      name        = "rip-terraform-state"
      versioning  = true
      object_lock = false
    }
    container_mirror = {
      name        = "rip-container-registry-mirror"
      versioning  = true
      object_lock = false
    }
    edge_staging = {
      name        = "rip-edge-image-staging"
      versioning  = true
      object_lock = false
    }
  }
}

resource "aws_s3_bucket" "foundation" {
  for_each = local.buckets

  bucket = "${each.value.name}-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name    = each.value.name
    Purpose = each.key
  })
}

resource "aws_s3_bucket_versioning" "foundation" {
  for_each = aws_s3_bucket.foundation

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "foundation" {
  for_each = aws_s3_bucket.foundation

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "foundation" {
  for_each = aws_s3_bucket.foundation

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.foundation["terraform_state"].arn, "${aws_s3_bucket.foundation["terraform_state"].arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.foundation["terraform_state"].id
  policy = data.aws_iam_policy_document.terraform_state.json
}

output "bucket_names" {
  value = { for k, v in aws_s3_bucket.foundation : k => v.id }
}

output "terraform_state_bucket_arn" {
  value = aws_s3_bucket.foundation["terraform_state"].arn
}
