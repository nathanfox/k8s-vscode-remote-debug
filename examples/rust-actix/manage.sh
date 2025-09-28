#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."

source "${ROOT_DIR}/shared/scripts/common-functions.sh"
export COMMON_SOURCED=1

source "${ROOT_DIR}/shared/scripts/k8s-helpers.sh"
export K8S_SOURCED=1

readonly VERSION="0.1.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly APP_NAME="rust-actix"
readonly IMAGE_NAME="rust-actix"

IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-}"

show_help() {
    cat << EOF
Rust Actix-web - Management Script v${VERSION}

Usage: $SCRIPT_NAME [OPTIONS] COMMAND

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL
    -t, --tag TAG              Docker image tag (default: latest)
    -p, --pod POD_NAME         Specific pod name (default: auto-detect first pod)
    -d, --debug                Enable debug output
    -h, --help                 Show this help message

COMMANDS:
    build                      Build Docker image (with LLDB)
    push                       Push image to registry
    deploy                     Deploy to namespace
    debug                      Verify pod ready and port-forward debug port (10586)
    port-forward [PORT]        Port-forward app port (default: 8080)
    port-forward-debug         Port-forward debug port (10586)
    logs [OPTIONS]             Show logs
        --follow|-f            Follow log output
        --tail N               Number of lines to show
    delete                     Delete from namespace
    shell                      Exec into pod
    restart                    Restart deployment
    status                     Show deployment status
    help                       Show this help message

EXAMPLES:
    # Build and deploy with default namespace
    $SCRIPT_NAME build
    $SCRIPT_NAME deploy

    # Deploy to specific namespace with custom registry
    $SCRIPT_NAME -n production -r myregistry.io deploy

    # Forward debug port and attach debugger
    $SCRIPT_NAME port-forward-debug

    # View logs
    $SCRIPT_NAME logs --follow

For more information, see the README.md in this directory.
EOF
}

cmd_build() {
    log_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"

    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        full_image_name="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    docker build \
        -t "${full_image_name}" \
        -f "${SCRIPT_DIR}/Dockerfile" \
        "${SCRIPT_DIR}"

    log_success "Image built: ${full_image_name}"
}

cmd_push() {
    require_command docker

    if [ -z "$REGISTRY" ]; then
        log_error "Registry not specified. Use -r/--registry flag or set REGISTRY env var"
        exit 1
    fi

    local full_image_name="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

    log_info "Pushing image: ${full_image_name}"
    docker push "${full_image_name}"
    log_success "Image pushed: ${full_image_name}"
}

cmd_deploy() {
    require_namespace
    check_kubectl

    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        full_image_name="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    log_info "Deploying ${APP_NAME} to namespace: $NAMESPACE"
    log_info "Using image: ${full_image_name}"

    local temp_manifest=$(mktemp -d)
    cp -r "${SCRIPT_DIR}/k8s"/* "$temp_manifest/"

    sed -i.bak "s|image: ${IMAGE_NAME}:latest|image: ${full_image_name}|g" "$temp_manifest/deployment.yaml"

    apply_manifests "$NAMESPACE" "$temp_manifest"

    rm -rf "$temp_manifest"

    log_info "Waiting for deployment to be ready..."
    wait_for_deployment_ready "$NAMESPACE" "$APP_NAME" 120

    local pod_name
    pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")

    log_success "Deployment ready: $APP_NAME"
    log_info "Pod: $pod_name"
}

cmd_debug() {
    require_namespace
    check_kubectl

    log_info "Setting up Rust debugging with LLDB..."

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Auto-detected pod: $pod_name"
    else
        log_info "Using specified pod: $pod_name"
    fi

    local status
    status=$(get_pod_status "$NAMESPACE" "$pod_name")

    if [ "$status" != "Running" ]; then
        log_error "Pod is not running. Status: $status"
        log_info "Run: $SCRIPT_NAME -n $NAMESPACE logs"
        exit 1
    fi

    log_success "Pod is ready for debugging: $pod_name"
    log_info ""
    log_info "Port-forwarding LLDB debug port 10586..."
    port_forward_pod "$NAMESPACE" "$pod_name" "10586" "10586"
}

cmd_port_forward_debug() {
    require_namespace
    check_kubectl

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Auto-detected pod: $pod_name"
    else
        log_info "Using specified pod: $pod_name"
    fi

    log_info "Port-forwarding LLDB debug port 10586..."
    port_forward_pod "$NAMESPACE" "$pod_name" "10586" "10586"
}

cmd_port_forward() {
    require_namespace
    check_kubectl

    local port="${1:-8080}"

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Auto-detected pod: $pod_name"
    else
        log_info "Using specified pod: $pod_name"
    fi

    log_info "Port-forwarding app port $port..."
    port_forward_pod "$NAMESPACE" "$pod_name" "$port" "$port"
}

cmd_logs() {
    require_namespace
    check_kubectl

    local follow=false
    local tail=50

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow)
                follow=true
                shift
                ;;
            --tail)
                tail="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Showing logs for pod: $pod_name"
    else
        log_info "Showing logs for specified pod: $pod_name"
    fi

    get_pod_logs "$NAMESPACE" "$pod_name" "$follow" "$tail"
}

cmd_delete() {
    require_namespace
    check_kubectl

    log_info "Deleting ${APP_NAME} from namespace: $NAMESPACE"
    delete_manifests "$NAMESPACE" "${SCRIPT_DIR}/k8s"
}

cmd_shell() {
    require_namespace
    check_kubectl

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
        log_info "Opening shell in pod: $pod_name"
    else
        log_info "Opening shell in specified pod: $pod_name"
    fi

    exec_in_pod "$NAMESPACE" "$pod_name"
}

cmd_restart() {
    require_namespace
    check_kubectl

    restart_deployment "$NAMESPACE" "$APP_NAME"
}

cmd_status() {
    require_namespace
    check_kubectl

    log_info "Status for ${APP_NAME} in namespace: $NAMESPACE"
    echo ""
    kubectl get deployment,pod,service -n "$NAMESPACE" -l app="$APP_NAME"
}

main() {
    parse_args "$@"
    shift $ARGS_SHIFT 2>/dev/null || true

    local command="${1:-help}"
    shift || true

    case "$command" in
        build)
            cmd_build "$@"
            ;;
        push)
            cmd_push "$@"
            ;;
        deploy)
            cmd_deploy "$@"
            ;;
        debug)
            cmd_debug "$@"
            ;;
        port-forward)
            cmd_port_forward "$@"
            ;;
        port-forward-debug)
            cmd_port_forward_debug "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        delete)
            cmd_delete "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"