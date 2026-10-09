terraform {
  required_version = ">= 1.6.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubectl_manifest" "cluster_secret_store" {
  depends_on = [helm_release.external_secrets]
  yaml_body  = file("${path.module}/manifests/cluster-secret-store.yaml")
}

resource "kubectl_manifest" "external_secret" {
  depends_on = [kubectl_manifest.cluster_secret_store]
  yaml_body  = file("${path.module}/manifests/external-secret-mock.yaml")
}
