#!/bin/bash

set -e

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${COLOR_YELLOW}[DEBUG]${COLOR_RESET} $*" >&2
    fi
}

require_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        log_error "Please install $cmd and try again"
        exit 1
    fi
}

require_namespace() {
    if [ -z "$NAMESPACE" ]; then
        log_error "Namespace not specified"
        log_error "Use -n/--namespace flag or set NAMESPACE environment variable"
        exit 1
    fi
}

parse_args() {
    ARGS_SHIFT=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ARGS_SHIFT=$((ARGS_SHIFT + 2))
                ;;
            -r|--registry)
                REGISTRY="$2"
                shift 2
                ARGS_SHIFT=$((ARGS_SHIFT + 2))
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ARGS_SHIFT=$((ARGS_SHIFT + 2))
                ;;
            -p|--pod)
                POD_NAME="$2"
                shift 2
                ARGS_SHIFT=$((ARGS_SHIFT + 2))
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ARGS_SHIFT=$((ARGS_SHIFT + 1))
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "${SCRIPT_NAME:-manage.sh} version ${VERSION:-dev}"
                exit 0
                ;;
            -*)
                if [ $# -eq 1 ]; then
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                break
                ;;
            *)
                break
                ;;
        esac
    done
}

confirm_action() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -r -p "$prompt" response
    response=${response:-$default}

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_condition() {
    local description=$1
    local timeout=${2:-60}
    local condition=$3

    log_info "Waiting for: $description (timeout: ${timeout}s)"

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition" &>/dev/null; then
            log_success "$description"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done

    echo ""
    log_error "Timeout waiting for: $description"
    return 1
}

check_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    return 0
}

check_dir_exists() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        log_error "Directory not found: $dir"
        return 1
    fi
    return 0
}

get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

export -f log_info
export -f log_success
export -f log_warn
export -f log_error
export -f log_debug
export -f require_command
export -f require_namespace
export -f parse_args
export -f confirm_action
export -f wait_for_condition
export -f check_file_exists
export -f check_dir_exists
export -f get_script_dir