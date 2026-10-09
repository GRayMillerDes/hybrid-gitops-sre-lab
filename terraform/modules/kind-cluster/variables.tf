variable "cluster_name" {
  type        = string
  description = "Name of the Kind Kubernetes cluster"
  default     = "hybrid-gitops-sre-lab"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes node image version"
  default     = "v1.28.0"
}
