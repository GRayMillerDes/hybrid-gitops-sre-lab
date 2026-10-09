output "kubernetes_endpoint" {
  description = "The local Kubernetes API server endpoint"
  value       = module.kind_cluster.endpoint
}

output "argocd_ui_url" {
  description = "Local endpoint for Argo CD Web UI"
  value       = "http://localhost:30080"
}

output "grafana_ui_url" {
  description = "Local endpoint for Grafana Golden Signals Dashboard"
  value       = "http://localhost:30000"
}

output "zero_trust_status" {
  description = "Verification instructions for ESO in-memory secret sync"
  value       = "Run 'kubectl get externalsecrets -A' and 'kubectl get secret mock-db-credentials -n default -o yaml' to verify zero plaintext leaks."
}
