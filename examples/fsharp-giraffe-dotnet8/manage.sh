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
readonly APP_NAME="fsharp-giraffe"
readonly IMAGE_NAME="fsharp-giraffe"

IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-}"

show_help() {
    cat << EOF
F# Giraffe .NET 8 - Management Script v${VERSION}

Usage: $SCRIPT_NAME [OPTIONS] COMMAND

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL
    -t, --tag TAG              Docker image tag (default: latest)
    -d, --debug                Enable debug output
    -h, --help                 Show this help message

COMMANDS:
    build                      Build Docker image (debug mode)
    push                       Push image to registry
    deploy                     Deploy to namespace
    debug                      Setup debugging (no port-forward needed for .NET)
    port-forward [PORT]        Port-forward app port (default: 8080)
    logs [OPTIONS]             Show logs
        --follow|-f            Follow log output
        --tail N               Number of lines to show
    delete                     Delete from namespace
    shell                      Exec into pod
    restart                    Restart deployment
    status                     Show deployment status
    help                       Show this help message

EXAMPLES:
    # Build and deploy
    $SCRIPT_NAME build
    $SCRIPT_NAME -n dev-yourname deploy

    # Debug (just ensures pod is ready - VS Code uses kubectl exec)
    $SCRIPT_NAME -n dev-yourname debug

    # Port-forward application
    $SCRIPT_NAME -n dev-yourname port-forward

    # View logs
    $SCRIPT_NAME -n dev-yourname logs --follow

EOF
}

cmd_build() {
    log_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"

    local full_image_name="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        full_image_name="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    fi

    docker build \
        --build-arg BUILD_MODE=debug \
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

    log_info "Checking pod status for debugging..."

    local pod_name
    pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")

    local status
    status=$(get_pod_status "$NAMESPACE" "$pod_name")

    if [ "$status" != "Running" ]; then
        log_error "Pod is not running. Status: $status"
        log_info "Run: $SCRIPT_NAME -n $NAMESPACE logs"
        exit 1
    fi

    log_success "Pod is ready for debugging: $pod_name"
    log_info ""
    log_info "To debug:"
    log_info "  1. Ensure NAMESPACE env var is set: export NAMESPACE=$NAMESPACE"
    log_info "  2. Open this folder in VS Code"
    log_info "  3. Press F5 or select 'Attach to Remote Pod'"
    log_info "  4. Set breakpoints and test endpoints"
    log_info ""
    log_info "Test endpoint:"
    log_info "  kubectl port-forward -n $NAMESPACE pod/$pod_name 8080:8080"
    log_info "  curl http://localhost:8080/debug-test?count=5"
}

cmd_port_forward() {
    require_namespace
    check_kubectl

    local local_port="${1:-8080}"
    local remote_port="8080"

    local pod_name
    pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")

    port_forward_pod "$NAMESPACE" "$pod_name" "$local_port" "$remote_port"
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
                break
                ;;
        esac
    done

    local pod_name
    pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")

    get_pod_logs "$NAMESPACE" "$pod_name" "$follow" "$tail"
}

cmd_delete() {
    require_namespace
    check_kubectl

    log_info "Deleting ${APP_NAME} from namespace: $NAMESPACE"

    delete_manifests "$NAMESPACE" "${SCRIPT_DIR}/k8s"

    log_success "Deleted: $APP_NAME"
}

cmd_shell() {
    require_namespace
    check_kubectl

    local pod_name
    pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")

    exec_in_pod "$NAMESPACE" "$pod_name" "/bin/bash"
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
        port-forward|pf)
            cmd_port_forward "$@"
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
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$SCRIPT_NAME help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"