terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26.0"
    }
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

# 1. Provision Local Multi-Node Kind Sandbox
module "kind_cluster" {
  source             = "./modules/kind-cluster"
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
}

# Provider configurations dynamically bound to Kind output
provider "kubernetes" {
  host                   = module.kind_cluster.endpoint
  client_certificate     = module.kind_cluster.client_certificate
  client_key             = module.kind_cluster.client_key
  cluster_ca_certificate = module.kind_cluster.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.kind_cluster.endpoint
    client_certificate     = module.kind_cluster.client_certificate
    client_key             = module.kind_cluster.client_key
    cluster_ca_certificate = module.kind_cluster.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = module.kind_cluster.endpoint
  client_certificate     = module.kind_cluster.client_certificate
  client_key             = module.kind_cluster.client_key
  cluster_ca_certificate = module.kind_cluster.cluster_ca_certificate
  load_config_file       = false
}

# 2. Deploy Argo CD Control Plane
resource "helm_release" "argocd" {
  depends_on       = [module.kind_cluster]
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  values = [
    <<-EOT
    server:
      service:
        type: NodePort
        nodePortHttp: 30080
      insecure: true
    configs:
      params:
        server.insecure: true
    EOT
  ]
}

# 3. Deploy External Secrets Operator (ESO) Zero-Trust Module
module "eso_secret_store" {
  depends_on = [module.kind_cluster]
  source     = "./modules/eso-secret-store"
}

# 4. Deploy Prometheus & Grafana Observability Stack
module "observability_stack" {
  count      = var.enable_observability ? 1 : 0
  depends_on = [module.kind_cluster]
  source     = "./modules/observability-stack"
}
