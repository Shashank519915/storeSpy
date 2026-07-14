variable "name" {
  type = string
}

variable "services" {
  type = list(string)
  default = [
    "api-gateway",
    "portal",
    "edge-bridge",
    "cv-orchestrator",
  ]
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name                 = "rip/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name    = "rip/${each.value}"
    Service = each.value
  })
}

output "repository_arns" {
  value = [for repo in aws_ecr_repository.services : repo.arn]
}

output "repository_urls" {
  value = { for k, repo in aws_ecr_repository.services : k => repo.repository_url }
}
