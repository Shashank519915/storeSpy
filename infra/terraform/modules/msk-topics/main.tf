variable "environment" {
  type    = string
  default = "dev"
}

variable "replication_factor" {
  type    = number
  default = 3
}

variable "min_insync_replicas" {
  type    = number
  default = 2
}

locals {
  # Dev uses fewer partitions; staging/prod use plan defaults (RIP-1-012).
  business_partitions  = var.environment == "dev" ? 6 : 24
  telemetry_partitions = var.environment == "dev" ? 12 : 96

  consumer_domains = [
    "vision.interaction",
    "vision.tracking",
    "twin.mutations",
    "retail.pos",
    "lp.engine",
  ]

  domain_topics = {
    "vision.tracking.tracklet-updated" = {
      partitions = local.telemetry_partitions
      domain     = "vision.tracking"
    }
    "vision.interaction.product-picked-up" = {
      partitions = local.business_partitions
      domain     = "vision.interaction"
    }
    "vision.interaction.product-returned" = {
      partitions = local.business_partitions
      domain     = "vision.interaction"
    }
    "vision.interaction.concealment-detected" = {
      partitions = local.business_partitions
      domain     = "vision.interaction"
    }
    "retail.pos.transaction-event" = {
      partitions = local.business_partitions
      domain     = "retail.pos"
    }
    "twin.mutations.layout-changed" = {
      partitions = local.business_partitions
      domain     = "twin.mutations"
    }
    "twin.mutations.camera-pitch-changed" = {
      partitions = local.business_partitions
      domain     = "twin.mutations"
    }
    "twin.mutations.shelf-moved" = {
      partitions = local.business_partitions
      domain     = "twin.mutations"
    }
    "lp.engine.hypothesis-updated" = {
      partitions = local.business_partitions
      domain     = "lp.engine"
    }
    "lp.engine.investigation-task-created" = {
      partitions = local.business_partitions
      domain     = "lp.engine"
    }
  }

  retry_topics = {
    for pair in setproduct(local.consumer_domains, ["retry-1", "retry-2", "retry-3", "dlq"]) :
    "${pair[0]}.${pair[1]}" => {
      partitions = 3
      domain     = pair[0]
      kind       = pair[1]
    }
  }

  all_topics = merge(local.domain_topics, local.retry_topics)
}

output "topics" {
  description = "Topic manifest for MSK bootstrap Job (TFC cannot reach private brokers)"
  value = {
    for name, cfg in local.all_topics : name => {
      partitions          = cfg.partitions
      replication_factor  = var.replication_factor
      min_insync_replicas = var.min_insync_replicas
      cleanup_policy      = "delete"
      retention_ms        = 604800000
    }
  }
}

output "domain_topics" {
  value = local.domain_topics
}

output "retry_topics" {
  value = local.retry_topics
}
