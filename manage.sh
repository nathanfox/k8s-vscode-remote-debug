#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/shared/scripts/common-functions.sh"
export COMMON_SOURCED=1

source "${SCRIPT_DIR}/shared/scripts/k8s-helpers.sh"
export K8S_SOURCED=1

readonly VERSION="0.1.0"
readonly SCRIPT_NAME=$(basename "$0")

show_help() {
    cat << EOF
Kubernetes Remote Debugging Examples - Management Script v${VERSION}

Usage: $SCRIPT_NAME [OPTIONS] COMMAND [ARGS]

OPTIONS:
    -n, --namespace NAMESPACE   Kubernetes namespace (or set NAMESPACE env var)
    -r, --registry REGISTRY     Docker registry URL (or set REGISTRY env var)
    -t, --tag TAG              Docker image tag (default: latest)
    -d, --debug                Enable debug output
    -v, --version              Show version
    -h, --help                 Show this help message

COMMANDS:
    === Namespace Management ===
    create-ns                  Create developer namespace
    delete-ns                  Delete namespace and all resources
    list-ns                    List all namespaces

    === Example Deployment ===
    deploy EXAMPLE             Deploy specific example to namespace
    deploy-all                 Deploy all available examples
    delete EXAMPLE             Delete specific example from namespace
    delete-all                 Delete all examples from namespace

    === Debugging ===
    debug EXAMPLE              Setup debugging for example (port-forward)
    logs EXAMPLE [OPTIONS]     Show logs for example
        --follow|-f            Follow log output
        --tail N               Number of lines to show (default: 50)

    === Status & Information ===
    status                     Show all pods in namespace
    list-examples              List available examples
    help                       Show this help message

EXAMPLES:
    # Create a developer namespace
    $SCRIPT_NAME create-ns -n dev-alice

    # Deploy an example
    $SCRIPT_NAME -n dev-alice deploy csharp

    # Setup debugging
    $SCRIPT_NAME -n dev-alice debug csharp

    # View logs
    $SCRIPT_NAME -n dev-alice logs csharp --follow

    # Check status
    $SCRIPT_NAME -n dev-alice status

    # Using environment variable
    export NAMESPACE=dev-alice
    $SCRIPT_NAME deploy csharp
    $SCRIPT_NAME debug csharp

ENVIRONMENT VARIABLES:
    NAMESPACE               Default namespace for operations
    REGISTRY               Docker registry URL
    IMAGE_TAG              Docker image tag (default: latest)
    DEBUG                  Enable debug output (0/1)

AVAILABLE EXAMPLES:
    csharp                 C# .NET 8 Web API
    fsharp                 F# Giraffe .NET 8
    nodejs                 Node.js Express
    python                 Python FastAPI
    go                     Go Gin

For more information, see: https://github.com/nathanfox/k8s-vscode-remote-debug

EOF
}

list_examples() {
    log_info "Available examples:"
    echo ""

    local examples_dir="${SCRIPT_DIR}/examples"

    if [ ! -d "$examples_dir" ]; then
        log_warn "No examples directory found"
        return 0
    fi

    for example_dir in "$examples_dir"/*; do
        if [ -d "$example_dir" ]; then
            local example_name=$(basename "$example_dir")
            local readme="${example_dir}/README.md"

            if [ -f "$readme" ]; then
                echo "  • ${example_name}"
            else
                echo "  • ${example_name} (in development)"
            fi
        fi
    done

    echo ""
}

get_example_dir() {
    local example=$1
    local example_dir="${SCRIPT_DIR}/examples/${example}"

    if [ ! -d "$example_dir" ]; then
        log_error "Example not found: $example"
        log_info "Run '$SCRIPT_NAME list-examples' to see available examples"
        return 1
    fi

    echo "$example_dir"
}

call_example_script() {
    local example=$1
    local command=$2
    shift 2

    local example_dir
    example_dir=$(get_example_dir "$example") || return 1

    local manage_script="${example_dir}/manage.sh"

    if [ ! -f "$manage_script" ]; then
        log_error "Management script not found: $manage_script"
        return 1
    fi

    log_debug "Calling: $manage_script $command $*"

    cd "$example_dir"
    bash "$manage_script" "$command" "$@"
}

cmd_create_ns() {
    require_namespace

    local labels="type=dev-namespace"

    create_namespace "$NAMESPACE" "$labels"
}

cmd_delete_ns() {
    require_namespace

    delete_namespace "$NAMESPACE"
}

cmd_list_ns() {
    check_kubectl

    log_info "Namespaces:"
    echo ""
    kubectl get namespaces -l type=dev-namespace 2>/dev/null || kubectl get namespaces
}

cmd_deploy() {
    local example=$1

    if [ -z "$example" ]; then
        log_error "Example name required"
        log_info "Usage: $SCRIPT_NAME -n NAMESPACE deploy EXAMPLE"
        return 1
    fi

    require_namespace

    log_info "Deploying example: $example to namespace: $NAMESPACE"

    call_example_script "$example" "deploy"
}

cmd_deploy_all() {
    require_namespace

    log_info "Deploying all examples to namespace: $NAMESPACE"

    local examples_dir="${SCRIPT_DIR}/examples"

    for example_dir in "$examples_dir"/*; do
        if [ -d "$example_dir" ] && [ -f "${example_dir}/manage.sh" ]; then
            local example_name=$(basename "$example_dir")
            log_info "Deploying: $example_name"
            call_example_script "$example_name" "deploy" || log_warn "Failed to deploy: $example_name"
        fi
    done

    log_success "All examples deployed"
}

cmd_delete() {
    local example=$1

    if [ -z "$example" ]; then
        log_error "Example name required"
        log_info "Usage: $SCRIPT_NAME -n NAMESPACE delete EXAMPLE"
        return 1
    fi

    require_namespace

    log_info "Deleting example: $example from namespace: $NAMESPACE"

    call_example_script "$example" "delete"
}

cmd_delete_all() {
    require_namespace

    log_warn "This will delete all examples from namespace: $NAMESPACE"
    if ! confirm_action "Are you sure?" "n"; then
        log_info "Cancelled"
        return 0
    fi

    local examples_dir="${SCRIPT_DIR}/examples"

    for example_dir in "$examples_dir"/*; do
        if [ -d "$example_dir" ] && [ -f "${example_dir}/manage.sh" ]; then
            local example_name=$(basename "$example_dir")
            log_info "Deleting: $example_name"
            call_example_script "$example_name" "delete" || log_warn "Failed to delete: $example_name"
        fi
    done

    log_success "All examples deleted"
}

cmd_debug() {
    local example=$1

    if [ -z "$example" ]; then
        log_error "Example name required"
        log_info "Usage: $SCRIPT_NAME -n NAMESPACE debug EXAMPLE"
        return 1
    fi

    require_namespace

    log_info "Setting up debugging for: $example in namespace: $NAMESPACE"

    call_example_script "$example" "debug"
}

cmd_logs() {
    local example=$1
    shift

    if [ -z "$example" ]; then
        log_error "Example name required"
        log_info "Usage: $SCRIPT_NAME -n NAMESPACE logs EXAMPLE [--follow]"
        return 1
    fi

    require_namespace

    call_example_script "$example" "logs" "$@"
}

cmd_status() {
    require_namespace

    get_namespace_status "$NAMESPACE"
}

main() {
    parse_args "$@"
    shift $ARGS_SHIFT 2>/dev/null || true

    local command="${1:-help}"
    shift || true

    case "$command" in
        create-ns)
            cmd_create_ns "$@"
            ;;
        delete-ns)
            cmd_delete_ns "$@"
            ;;
        list-ns)
            cmd_list_ns "$@"
            ;;
        deploy)
            cmd_deploy "$@"
            ;;
        deploy-all)
            cmd_deploy_all "$@"
            ;;
        delete)
            cmd_delete "$@"
            ;;
        delete-all)
            cmd_delete_all "$@"
            ;;
        debug)
            cmd_debug "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        list-examples)
            list_examples
            ;;
        help|--help|-h)
            show_help
            ;;
        version|--version|-v)
            echo "$SCRIPT_NAME version $VERSION"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$SCRIPT_NAME help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"