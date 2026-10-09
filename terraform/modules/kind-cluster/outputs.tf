output "endpoint" {
  description = "The Kubernetes control plane endpoint"
  value       = kind_cluster.default.endpoint
}

output "kubeconfig" {
  description = "Raw kubeconfig output"
  value       = kind_cluster.default.kubeconfig
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate for Kubernetes provider auth"
  value       = kind_cluster.default.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for Kubernetes provider auth"
  value       = kind_cluster.default.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate for Kubernetes provider auth"
  value       = kind_cluster.default.cluster_ca_certificate
  sensitive   = true
}
