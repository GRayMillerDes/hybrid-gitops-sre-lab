# Architecture Deep Dive & Zero-Trust Governance

This document describes the architectural design, security boundaries, and telemetry foundations implemented in the **Enterprise Hybrid GitOps & SRE Sandbox**.

---

## 1. Design Principles

1. **Zero Plaintext State (Least-Privilege State Delivery)**:
   - Credentials must never be declared in `values = [yamlencode(...)]` within Terraform or Helm code.
   - Terraform manages declarative infrastructure definitions and Custom Resource Definitions (CRDs). Runtime secrets are delegated dynamically to [External Secrets Operator (ESO)](https://external-secrets.io/).

2. **Zero-ClickOps & Drift Self-Healing**:
   - Applications are synchronized using Argo CD's **App-of-Apps** pattern.
   - Any manual modifications (`kubectl edit`, console drift) trigger automated out-of-sync notifications and self-healing reconciliation.

3. **Restricted Workload Privileges (CIS Benchmark Compliance)**:
   - All managed controller workloads enforce:
     - `runAsUser: 1000` (strictly non-root execution)
     - `readOnlyRootFilesystem: true`
     - `allowPrivilegeEscalation: false`
     - `capabilities.drop: ["ALL"]`
     - `seccompProfile.type: RuntimeDefault`

4. **Non-Interactive Diagnostic Hooks**:
   - In financial and high-security compliance zones, platform engineers are prohibited from running `kubectl exec`, `kubectl attach`, or `kubectl port-forward` inside production namespaces.
   - Root-cause analysis (RCA) must rely on non-interactive automated log extraction pipelines targeting `.status.containerStatuses` and `--previous` stderr streams.

---

## 2. Component Topology

| Component | Layer | Responsibilities | Security Context |
| :--- | :--- | :--- | :--- |
| **Kind Cluster** | Infrastructure | Simulates multi-node heterogeneous multi-cloud topology (AWS & TKE zones) | Node labels, Ingress & NodePort bindings |
| **Terraform 1.6+** | Platform Orchestration | Declarative cluster bootstrap, Helm provider glue, zero-secret state enforcement | Automated execution via TF Cloud / local runners |
| **Argo CD** | GitOps Delivery | App-of-Apps management, drift detection, continuous synchronization | Insecure mode for local sandbox demo |
| **External Secrets Operator** | Secret Fabric | Synchronizes secrets from simulated cloud providers directly into in-memory K8s Secret resources | Scoped ClusterSecretStore |
| **CloudBees MC Template** | Workload Data Plane | Emulates multi-tenant build controllers with dynamic CasC configurations | CIS-hardened, non-root, read-only root FS |
| **Prometheus / Alertmanager** | Observability | Scrapes cluster metrics, evaluates multi-window SLO burn rates, detects CrashLoopBackOff | Monitoring namespace isolation |
| **Grafana** | Visualization | Golden Signals dashboards (Latency, Traffic, Errors, Saturation) | NodePort 30000 |

---

## 3. High-Resolution Architecture Topology

![Architecture Topology](./topology-diagram.svg)

```mermaid
graph TB
    %% Styling and Class Definitions
    classDef client fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef control fill:#1e1b4b,stroke:#818cf8,stroke-width:2px,color:#f8fafc;
    classDef aws fill:#451a03,stroke:#fbbf24,stroke-width:2px,color:#fef3c7;
    classDef tke fill:#14532d,stroke:#34d399,stroke-width:2px,color:#ecfdf5;
    classDef obs fill:#701a75,stroke:#f472b6,stroke-width:2px,color:#fdf2f8;
    classDef secret fill:#022c22,stroke:#10b981,stroke-width:2px,color:#d1fae5;

    subgraph WORKSTATION["💻 Local Workstation / CI Runner"]
        TF["🏗️ Terraform 1.6+<br/>• Kind Multi-Node Engine<br/>• Zero-Secret State Providers"]:::client
        DIAG["🩺 SRE Diagnostic Script<br/>• non-interactive-diag.sh<br/>• Exit Code & Stderr Triage"]:::client
    end

    subgraph CONTROL_PLANE["☸️ Local Kind Control Plane (v1.28+)"]
        API["🚪 Kubernetes API Server<br/>NodePort 30080 / 30000"]:::control
        ARGO["🐙 Argo CD GitOps<br/>• App-of-Apps Pattern<br/>• Automated Drift Self-Healing"]:::control
        ESO["🔐 External Secrets Operator<br/>• ClusterSecretStore CRD<br/>• ExternalSecret Reconciliation"]:::secret
        MOCK_STORE[("☁️ Simulated Cloud Vault<br/>AWS SSM / Vault Secret Provider")]:::secret
    end

    subgraph DATA_PLANE["⚡ Workload Data Plane (Simulated Multi-Cloud)"]
        subgraph NODE_AWS["🟠 Worker 1: AWS Simulation Node"]
            MC_AWS["🐝 CloudBees MC - AWS Apps<br/>• runAsUser: 1000<br/>• Read-only Root FS<br/>• Dynamic CasC Injection"]:::aws
            SECRET_AWS[("🔑 K8s Secret (In-Memory)<br/>mock-db-credentials")]:::secret
        end

        subgraph NODE_TKE["🟢 Worker 2: TKE Simulation Node"]
            MC_TKE["🐝 CloudBees MC - TKE Platform<br/>• CIS Benchmark Hardened<br/>• Drop ALL Linux Caps"]:::tke
            SECRET_TKE[("🔑 K8s Secret (In-Memory)<br/>mock-db-credentials")]:::secret
        end
    end

    subgraph OBSERVABILITY["📊 Enterprise SRE Observability Stack"]
        PROM["🔥 Prometheus Core<br/>• SLO Burn Rate Multi-Window<br/>• CrashLoopBackOff Detection"]:::obs
        GRAF["📈 Grafana Dashboards<br/>• Golden Signals (Latency, Traffic, Errors, Saturation)"]:::obs
    end

    %% Workflows & Data Flows
    TF ==>|1. Declarative Bootstrap| API
    ARGO -->|2. GitOps Continuous Delivery| MC_AWS
    ARGO -->|2. GitOps Continuous Delivery| MC_TKE
    ESO <-->|3. Zero-Trust Fetch| MOCK_STORE
    ESO -.->|4. Inject Ephemeral Secret| SECRET_AWS
    ESO -.->|4. Inject Ephemeral Secret| SECRET_TKE
    SECRET_AWS -->|5. Mount Vault Env| MC_AWS
    SECRET_TKE -->|5. Mount Vault Env| MC_TKE

    PROM -.->|6. Scrape 15s Cadence| MC_AWS
    PROM -.->|6. Scrape 15s Cadence| MC_TKE
    GRAF -->|7. PromQL Metrics Queries| PROM
    DIAG -.->|8. Automated Non-Interactive Triage| MC_AWS
    DIAG -.->|8. Automated Non-Interactive Triage| MC_TKE
```
