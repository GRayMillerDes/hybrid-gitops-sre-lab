terraform {
  required_version = ">= 1.6.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26.0"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/part-of" = "observability-stack"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    <<-EOT
    grafana:
      adminPassword: "prom-operator"
      service:
        type: NodePort
        nodePort: 30000
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: 1
          providers:
          - name: 'golden-signals'
            orgId: 1
            folder: 'SRE Golden Signals'
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/golden-signals
      dashboards:
        golden-signals:
          sre-golden-signals:
            json: |
              ${indent(14, file("${path.module}/../../observability/dashboards/golden-signals.json"))}
    prometheus:
      prometheusSpec:
        ruleSelectorNilUsesHelmValues: false
        serviceMonitorSelectorNilUsesHelmValues: false
    EOT
  ]
}
