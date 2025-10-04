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
readonly APP_NAME="elixir-phoenix"
readonly IMAGE_NAME="elixir-phoenix"

IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-}"

show_help() {
    cat << EOF
Elixir Phoenix - Management Script v${VERSION}

Usage: $SCRIPT_NAME [OPTIONS] COMMAND

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL
    -t, --tag TAG              Docker image tag (default: latest)
    -p, --pod POD_NAME         Specific pod name (default: auto-detect first pod)
    -d, --debug                Enable debug output
    -h, --help                 Show this help message

COMMANDS:
    build                      Build Docker image (with distributed Erlang)
    push                       Push image to registry
    deploy                     Deploy to namespace
    debug                      Verify pod ready and port-forward debug ports (4369, 9000)
    start-phoenix              Start Phoenix server (after VS Code debugger attaches)
    port-forward [PORT]        Port-forward app port (default: 4000)
    port-forward-debug         Port-forward debug ports (4369, 9000)
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

    # Debug (port-forward EPMD and distribution ports)
    $SCRIPT_NAME -n dev-yourname debug
    # Then attach VS Code debugger (F5)

    # Debug specific pod (if multiple replicas)
    $SCRIPT_NAME -n dev-yourname -p elixir-phoenix-7b4465f95-s94w2 debug

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

    log_info "Setting up Elixir remote debugging with ElixirLS..."

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

    # Kill any existing port-forwards to this app
    log_info "Cleaning up any existing port-forwards..."
    pkill -f "port-forward.*$pod_name" 2>/dev/null || true
    sleep 1

    log_info "Port-forwarding EPMD (4369) and distribution (9000) ports..."
    log_info "Press Ctrl+C to stop port-forwarding"
    log_info ""
    # Port-forward both EPMD and distribution ports (standard EPMD and distribution ports)
    kubectl port-forward -n "$NAMESPACE" "pod/$pod_name" 4369:4369 9000:9000
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

    # Kill any existing port-forwards to this app
    log_info "Cleaning up any existing port-forwards..."
    pkill -f "port-forward.*$pod_name" 2>/dev/null || true
    sleep 1

    log_info "Port-forwarding distribution port (9000)..."
    kubectl port-forward -n "$NAMESPACE" "pod/$pod_name" 4369:4369 9000:9000
}

cmd_port_forward() {
    require_namespace
    check_kubectl

    local local_port="${1:-4000}"
    local remote_port="4000"

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
    fi

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

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
    fi

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

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
    fi

    log_info "Attaching to pod's main IEx session: $pod_name"
    log_info "This will connect directly to the running IEx console"
    log_info "If code hits IEx.pry(), you'll get an interactive debugging session"
    log_info "Press Ctrl+D or type 'exit' to detach (app will keep running)"
    log_info ""

    # Attach directly to the pod's stdin/stdout (main IEx session)
    kubectl attach -it -n "$NAMESPACE" "$pod_name"
}

cmd_restart() {
    require_namespace
    check_kubectl

    log_info "Restarting deployment: $APP_NAME"
    kubectl rollout restart deployment "$APP_NAME" -n "$NAMESPACE"
    kubectl rollout status deployment "$APP_NAME" -n "$NAMESPACE"
    log_success "Deployment restarted"
}

cmd_status() {
    require_namespace
    check_kubectl

    log_info "Deployment status for: $APP_NAME"
    kubectl get deployment "$APP_NAME" -n "$NAMESPACE"
    echo
    log_info "Pods:"
    kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME"
    echo
    log_info "Service:"
    kubectl get service "$APP_NAME" -n "$NAMESPACE"
}

cmd_start_phoenix() {
    require_namespace
    check_kubectl

    local pod_name="${POD_NAME:-}"
    if [ -z "$pod_name" ]; then
        pod_name=$(get_pod_name "$NAMESPACE" "$APP_NAME")
    fi

    log_info "Starting Phoenix server in pod: $pod_name"
    log_info "NOTE: Make sure VS Code debugger is attached BEFORE running this!"
    log_info ""

    # Get the Erlang cookie from the pod's environment
    local cookie
    cookie=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- printenv RELEASE_COOKIE 2>/dev/null || echo "debug_cookie_change_me")

    # Connect to the remote node and execute Mix.Task.run("phx.server")
    kubectl exec -n "$NAMESPACE" "$pod_name" -- \
        elixir --name temp_starter@pod.debug --cookie "$cookie" --eval \
        'Node.connect(:"elixir_phoenix@pod.debug") && :rpc.call(:"elixir_phoenix@pod.debug", Mix.Task, :run, ["phx.server"])'

    log_success "Phoenix start command sent to pod"
    log_info "Check logs to verify Phoenix started: ./manage.sh -n $NAMESPACE logs --follow"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -p|--pod)
            POD_NAME="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        build|push|deploy|debug|port-forward|port-forward-debug|logs|delete|shell|restart|status|start-phoenix)
            COMMAND=$1
            shift
            break
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute command
case ${COMMAND:-} in
    build)
        cmd_build
        ;;
    push)
        cmd_push
        ;;
    deploy)
        cmd_deploy
        ;;
    debug)
        cmd_debug
        ;;
    port-forward-debug)
        cmd_port_forward_debug
        ;;
    port-forward)
        cmd_port_forward "$@"
        ;;
    logs)
        cmd_logs "$@"
        ;;
    delete)
        cmd_delete
        ;;
    shell)
        cmd_shell
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    start-phoenix)
        cmd_start_phoenix
        ;;
    *)
        log_error "No command specified"
        show_help
        exit 1
        ;;
esac