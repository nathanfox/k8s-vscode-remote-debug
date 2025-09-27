#!/bin/bash

set -e

if [ -z "${COMMON_SOURCED}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/common-functions.sh"
fi

readonly DEFAULT_LABEL_APP="app"
readonly DEFAULT_WAIT_TIMEOUT=120

check_kubectl() {
    require_command kubectl
}

check_namespace_exists() {
    local namespace=$1

    check_kubectl

    if kubectl get namespace "$namespace" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

create_namespace() {
    local namespace=$1
    local labels=${2:-""}

    check_kubectl

    if check_namespace_exists "$namespace"; then
        log_warn "Namespace already exists: $namespace"
        return 0
    fi

    log_info "Creating namespace: $namespace"

    if [ -n "$labels" ]; then
        kubectl create namespace "$namespace" --dry-run=client -o yaml | \
            kubectl label --local -f - "$labels" -o yaml | \
            kubectl apply -f -
    else
        kubectl create namespace "$namespace"
    fi

    log_success "Namespace created: $namespace"
}

delete_namespace() {
    local namespace=$1
    local force=${2:-false}

    check_kubectl

    if ! check_namespace_exists "$namespace"; then
        log_warn "Namespace does not exist: $namespace"
        return 0
    fi

    if [ "$force" != "true" ]; then
        log_warn "This will delete namespace '$namespace' and all its resources"
        if ! confirm_action "Are you sure you want to delete namespace '$namespace'?" "n"; then
            log_info "Cancelled"
            return 1
        fi
    fi

    log_info "Deleting namespace: $namespace"
    kubectl delete namespace "$namespace"
    log_success "Namespace deleted: $namespace"
}

get_pods_by_label() {
    local namespace=$1
    local label=$2

    check_kubectl
    require_namespace

    kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}'
}

get_pod_name() {
    local namespace=$1
    local app_label=$2

    check_kubectl

    local pod_name
    pod_name=$(kubectl get pods -n "$namespace" -l "${DEFAULT_LABEL_APP}=${app_label}" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod_name" ]; then
        log_error "No pod found with label ${DEFAULT_LABEL_APP}=${app_label} in namespace $namespace"
        return 1
    fi

    echo "$pod_name"
}

get_pod_status() {
    local namespace=$1
    local pod_name=$2

    check_kubectl

    kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound"
}

wait_for_pod_ready() {
    local namespace=$1
    local pod_name=$2
    local timeout=${3:-$DEFAULT_WAIT_TIMEOUT}

    check_kubectl

    log_info "Waiting for pod to be ready: $pod_name (timeout: ${timeout}s)"

    if kubectl wait --for=condition=ready pod/"$pod_name" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_success "Pod is ready: $pod_name"
        return 0
    else
        log_error "Pod failed to become ready: $pod_name"
        return 1
    fi
}

wait_for_deployment_ready() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-$DEFAULT_WAIT_TIMEOUT}

    check_kubectl

    log_info "Waiting for deployment to be ready: $deployment (timeout: ${timeout}s)"

    if kubectl wait --for=condition=available deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_success "Deployment is ready: $deployment"
        return 0
    else
        log_error "Deployment failed to become ready: $deployment"
        return 1
    fi
}

port_forward_pod() {
    local namespace=$1
    local pod_name=$2
    local local_port=$3
    local remote_port=$4
    local background=${5:-false}

    check_kubectl

    log_info "Setting up port-forward: localhost:${local_port} -> ${pod_name}:${remote_port}"

    if [ "$background" = "true" ]; then
        kubectl port-forward -n "$namespace" "pod/$pod_name" "${local_port}:${remote_port}" &
        local pid=$!
        log_success "Port-forward started in background (PID: $pid)"
        echo "$pid"
    else
        log_info "Press Ctrl+C to stop port-forwarding"
        kubectl port-forward -n "$namespace" "pod/$pod_name" "${local_port}:${remote_port}"
    fi
}

exec_in_pod() {
    local namespace=$1
    local pod_name=$2
    shift 2
    local command=("$@")

    check_kubectl

    if [ ${#command[@]} -eq 0 ]; then
        command=("/bin/sh")
    fi

    log_info "Executing in pod: $pod_name"
    kubectl exec -it -n "$namespace" "$pod_name" -- "${command[@]}"
}

get_pod_logs() {
    local namespace=$1
    local pod_name=$2
    local follow=${3:-false}
    local tail=${4:-50}

    check_kubectl

    local args=("-n" "$namespace")

    if [ "$follow" = "true" ]; then
        args+=("-f")
    fi

    args+=("--tail=$tail" "$pod_name")

    kubectl logs "${args[@]}"
}

apply_manifests() {
    local namespace=$1
    local manifest_dir=$2

    check_kubectl

    if [ ! -d "$manifest_dir" ]; then
        log_error "Manifest directory not found: $manifest_dir"
        return 1
    fi

    log_info "Applying manifests from: $manifest_dir"

    kubectl apply -n "$namespace" -f "$manifest_dir"

    log_success "Manifests applied"
}

delete_manifests() {
    local namespace=$1
    local manifest_dir=$2

    check_kubectl

    if [ ! -d "$manifest_dir" ]; then
        log_error "Manifest directory not found: $manifest_dir"
        return 1
    fi

    log_info "Deleting resources from: $manifest_dir"

    kubectl delete -n "$namespace" -f "$manifest_dir" --ignore-not-found=true

    log_success "Resources deleted"
}

get_namespace_status() {
    local namespace=$1

    check_kubectl

    if ! check_namespace_exists "$namespace"; then
        log_error "Namespace does not exist: $namespace"
        return 1
    fi

    log_info "Status for namespace: $namespace"
    echo ""
    kubectl get all -n "$namespace"
}

restart_deployment() {
    local namespace=$1
    local deployment=$2

    check_kubectl

    log_info "Restarting deployment: $deployment"
    kubectl rollout restart deployment/"$deployment" -n "$namespace"

    wait_for_deployment_ready "$namespace" "$deployment"
}

export -f check_kubectl
export -f check_namespace_exists
export -f create_namespace
export -f delete_namespace
export -f get_pods_by_label
export -f get_pod_name
export -f get_pod_status
export -f wait_for_pod_ready
export -f wait_for_deployment_ready
export -f port_forward_pod
export -f exec_in_pod
export -f get_pod_logs
export -f apply_manifests
export -f delete_manifests
export -f get_namespace_status
export -f restart_deployment