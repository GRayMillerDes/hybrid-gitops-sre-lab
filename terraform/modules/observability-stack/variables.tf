variable "monitoring_namespace" {
  type        = string
  description = "Namespace for monitoring components"
  default     = "monitoring"
}

variable "kube_prometheus_chart_version" {
  type        = string
  description = "Helm chart version for kube-prometheus-stack"
  default     = "55.5.0"
}
