package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Deployment '%s' uses forbidden 'latest' tag on image '%s'", [input.metadata.name, container.image])
}

deny[msg] {
  input.kind == "StatefulSet"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("StatefulSet '%s' uses forbidden 'latest' tag", [input.metadata.name])
}

deny[msg] {
  input.kind == "Secret"
  input.type == "Opaque"
  some key
  value := input.data[key]
  # Detect base64-encoded literal passwords in manifests (heuristic)
  regex.match("(?i)(password|secret|token|apikey)", key)
  msg := sprintf("Secret '%s' may contain literal credential in key '%s' — use External Secrets Operator", [input.metadata.name, key])
}
