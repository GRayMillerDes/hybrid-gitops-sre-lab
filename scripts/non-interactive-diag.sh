#!/usr/bin/env bash
# ==============================================================================
# Enterprise SRE Diagnostic Script: Non-Interactive Pod & Sidecar Triage
# Designed for regulated environments under Least-Privilege Guardrails (No `kubectl exec`)
# ==============================================================================

set -euo pipefail

NAMESPACE="default"
POD_LABEL=""
CONTAINER_NAME=""
OUTPUT_DIR="/tmp/sre-diagnostics-$(date +%Y%m%d-%H%M%S)"
VERBOSE=false

function print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Non-Interactive diagnostic probe to extract termination exit codes,
container statuses, and stderr log streams under zero-exec security policies.

Options:
    -n, --namespace <ns>       Kubernetes namespace (default: default)
    -l, --pod-label <label>    Label selector (e.g., app=broken-worker)
    -c, --container <name>     Target specific container name (optional)
    -o, --output-dir <dir>     Directory to save diagnostic artifacts
    -v, --verbose              Enable verbose output
    -h, --help                 Display this help message

Examples:
    $(basename "$0") --namespace default --pod-label app=broken-worker
    $(basename "$0") -n production -l app=cloudbees-mc -c jnlp-sidecar
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -l|--pod-label)
            POD_LABEL="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift 1
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            echo "[-] Unknown option: $1" >&2
            print_usage
            ;;
    esac
done

if [[ -z "$POD_LABEL" ]]; then
    echo "[-] Error: --pod-label is required." >&2
    print_usage
fi

mkdir -p "$OUTPUT_DIR"

echo "=============================================================================="
echo " [SRE Proactive RCA] Non-Interactive Diagnostic Probe"
echo " Target Namespace : $NAMESPACE"
echo " Target Selector  : $POD_LABEL"
echo " Artifacts Dir    : $OUTPUT_DIR"
echo " Timestamp        : $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=============================================================================="

# 1. Fetch Pod List
echo "[*] Step 1: Discovering matching pods..."
PODS=$(kubectl get pods -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [[ -z "$PODS" ]]; then
    echo "[-] No pods found matching label '${POD_LABEL}' in namespace '${NAMESPACE}'."
    exit 1
fi

echo "[+] Found Pods: $PODS"

# 2. Iterate through pods and inspect container statuses
for POD in $PODS; do
    echo "------------------------------------------------------------------------------"
    echo "[*] Inspecting Pod: $POD"
    
    POD_JSON="$OUTPUT_DIR/${POD}.json"
    kubectl get pod "$POD" -n "$NAMESPACE" -o json > "$POD_JSON"
    
    PHASE=$(jq -r '.status.phase // "Unknown"' "$POD_JSON")
    RESTART_COUNT=$(jq -r '[.status.containerStatuses[]?.restartCount // 0] | add // 0' "$POD_JSON")
    echo "    Phase: $PHASE | Cumulative Restarts: $RESTART_COUNT"

    # Extract all containers (init + app)
    CONTAINERS=$(jq -r '[(.status.initContainerStatuses[]?.name // empty), (.status.containerStatuses[]?.name // empty)] | unique | .[]' "$POD_JSON")

    for C in $CONTAINERS; do
        if [[ -n "$CONTAINER_NAME" && "$C" != "$CONTAINER_NAME" ]]; then
            continue
        fi

        echo "    [*] Container: $C"
        
        # Query Waiting Reason
        WAITING_REASON=$(jq -r --arg c "$C" '
            (.status.containerStatuses[]? | select(.name == $c) | .state.waiting.reason) //
            (.status.initContainerStatuses[]? | select(.name == $c) | .state.waiting.reason) // "None"
        ' "$POD_JSON")
        
        # Query Last Terminated Exit Code & Reason
        EXIT_CODE=$(jq -r --arg c "$C" '
            (.status.containerStatuses[]? | select(.name == $c) | .lastState.terminated.exitCode) //
            (.status.initContainerStatuses[]? | select(.name == $c) | .lastState.terminated.exitCode) // "N/A"
        ' "$POD_JSON")
        
        TERM_REASON=$(jq -r --arg c "$C" '
            (.status.containerStatuses[]? | select(.name == $c) | .lastState.terminated.reason) //
            (.status.initContainerStatuses[]? | select(.name == $c) | .lastState.terminated.reason) // "N/A"
        ' "$POD_JSON")

        echo "        State/Waiting Reason : $WAITING_REASON"
        echo "        Last Exit Code       : $EXIT_CODE"
        echo "        Last Term Reason     : $TERM_REASON"

        # 3. Pull previous execution logs (tail 100)
        PREV_LOG_FILE="$OUTPUT_DIR/${POD}_${C}_previous.log"
        CURR_LOG_FILE="$OUTPUT_DIR/${POD}_${C}_current.log"

        echo "        Extracting previous log buffer..."
        if kubectl logs "$POD" -n "$NAMESPACE" -c "$C" --previous --tail=100 > "$PREV_LOG_FILE" 2>/dev/null; then
            echo "        [+] Previous logs extracted -> $PREV_LOG_FILE"
            echo "        --- [LAST 10 LINES OF PREVIOUS STDERR/STDOUT] ---"
            tail -n 10 "$PREV_LOG_FILE" | sed 's/^/            | /'
            echo "        -------------------------------------------------"
        else
            echo "        [-] No previous logs available (likely first container execution or evicted)."
            # Pull current logs if previous unavailable
            if kubectl logs "$POD" -n "$NAMESPACE" -c "$C" --tail=50 > "$CURR_LOG_FILE" 2>/dev/null; then
                echo "        [+] Current logs extracted -> $CURR_LOG_FILE"
                tail -n 10 "$CURR_LOG_FILE" | sed 's/^/            | /'
            fi
        fi
    done
done

echo "=============================================================================="
echo "[+] Diagnostic scan complete without requiring interactive shell access."
echo "[+] All diagnostic artifacts persisted in: $OUTPUT_DIR"
echo "=============================================================================="
