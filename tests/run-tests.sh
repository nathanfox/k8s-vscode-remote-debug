#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/test-framework.sh"

show_help() {
    cat << EOF
K8s Remote Debugging - Test Runner

Usage: $(basename "$0") [TYPE]

TYPES:
    quick                Run quick smoke tests
    unit                 Run unit tests
    integration          Run integration tests
    all                  Run all tests
    specific FILE        Run specific test file

ENVIRONMENT VARIABLES:
    VERBOSE=1            Show detailed test output
    QUIET=1              Suppress most output
    TEST_CLEANUP=0       Skip test namespace cleanup

EXAMPLES:
    # Quick tests
    ./tests/run-tests.sh quick

    # All unit tests
    ./tests/run-tests.sh unit

    # Verbose output
    VERBOSE=1 ./tests/run-tests.sh unit

    # Specific test file
    ./tests/run-tests.sh specific tests/unit/test-manage-commands.sh

EOF
}

run_test_file() {
    local test_file="$1"

    if [ ! -f "$test_file" ]; then
        log_error "Test file not found: $test_file"
        return 1
    fi

    log_info "Running: $test_file"
    bash "$test_file"
}

run_quick_tests() {
    log_info "Running quick smoke tests..."

    start_test_suite "Quick Tests"

    run_test_file "${SCRIPT_DIR}/unit/test-manage-commands.sh"

    end_test_suite "Quick Tests"
}

run_unit_tests() {
    log_info "Running unit tests..."

    local test_files=("${SCRIPT_DIR}/unit"/test-*.sh)

    if [ ${#test_files[@]} -eq 0 ]; then
        log_warning "No unit tests found"
        return 0
    fi

    for test_file in "${test_files[@]}"; do
        if [ -f "$test_file" ]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_integration_tests() {
    log_info "Running integration tests..."

    local test_files=("${SCRIPT_DIR}/integration"/test-*.sh)

    if [ ${#test_files[@]} -eq 0 ]; then
        log_warning "No integration tests found"
        return 0
    fi

    for test_file in "${test_files[@]}"; do
        if [ -f "$test_file" ]; then
            run_test_file "$test_file" || true
        fi
    done
}

run_all_tests() {
    log_info "Running all tests..."

    run_unit_tests
    echo ""
    run_integration_tests
}

main() {
    local test_type="${1:-all}"

    case "$test_type" in
        quick)
            run_quick_tests
            ;;
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        all)
            run_all_tests
            ;;
        specific)
            if [ -z "$2" ]; then
                log_error "Test file required for 'specific' type"
                echo "Usage: $0 specific PATH/TO/test-file.sh"
                exit 1
            fi
            run_test_file "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown test type: $test_type"
            show_help
            exit 1
            ;;
    esac
}

main "$@"