#!/usr/bin/env bash
# ==============================================================================
# One-Command Local Sandbox Bootstrapper
# Checks dependencies, provisions Kind cluster, ESO mock store & Observability
# ==============================================================================

set -euo pipefail

echo "=============================================================================="
echo " Starting Hybrid GitOps & SRE Sandbox Setup"
echo "=============================================================================="

# 1. Dependency Preflight
REQUIRED_CMDS=("docker" "kubectl" "terraform")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[-] Error: Missing required tool: $cmd" >&2
        exit 1
    fi
done

echo "[+] Preflight check passed: Docker, kubectl, and Terraform detected."

# Check docker daemon
if ! docker info &> /dev/null; then
    echo "[-] Error: Docker daemon is not running. Please start Docker Engine." >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"

echo "[*] Initializing Terraform infrastructure..."
cd "$TERRAFORM_DIR"

if [[ ! -f "terraform.tfvars" && -f "terraform.tfvars.example" ]]; then
    cp terraform.tfvars.example terraform.tfvars
    echo "[+] Generated terraform.tfvars from example template."
fi

terraform init -upgrade
terraform apply -auto-approve

echo "=============================================================================="
echo "[+] Sandbox is up and running!"
echo "    - Argo CD Web UI:  http://localhost:30080"
echo "    - Grafana Web UI:  http://localhost:30000 (admin / prom-operator)"
echo "    - Quick Verify:    kubectl get pods -A"
echo "=============================================================================="
