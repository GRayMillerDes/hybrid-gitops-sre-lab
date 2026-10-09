variable "cluster_name" {
  type        = string
  description = "Cluster name for the local Kind sandbox"
  default     = "hybrid-gitops-sre-lab"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes node image version"
  default     = "v1.28.0"
}

variable "argocd_chart_version" {
  type        = string
  description = "Helm chart version for Argo CD"
  default     = "5.51.6"
}

variable "enable_observability" {
  type        = bool
  description = "Whether to provision the Prometheus/Grafana observability stack"
  default     = true
}
