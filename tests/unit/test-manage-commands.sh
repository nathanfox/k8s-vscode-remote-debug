#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test-framework.sh"

MANAGE_SCRIPT="${SCRIPT_DIR}/../../manage.sh"

test_manage_script_exists() {
    assert_file_exists "$MANAGE_SCRIPT" "manage.sh should exist"
}

test_help_command() {
    local output
    output=$("$MANAGE_SCRIPT" help 2>&1)

    assert_contains "$output" "Usage:" "Help should show usage"
    assert_contains "$output" "COMMANDS:" "Help should list commands"
}

test_version_command() {
    local output
    output=$("$MANAGE_SCRIPT" version 2>&1)

    assert_contains "$output" "version" "Version should be displayed"
}

test_list_examples_command() {
    local output
    output=$("$MANAGE_SCRIPT" list-examples 2>&1)

    assert_contains_stripped "$output" "Available examples" "Should list available examples"
}

test_namespace_flag() {
    local output
    output=$("$MANAGE_SCRIPT" -n test-namespace status 2>&1 || true)

    assert_contains_stripped "$output" "test-namespace" "Should use namespace from flag"
}

test_namespace_env_var() {
    local output
    output=$(NAMESPACE=env-test-namespace "$MANAGE_SCRIPT" status 2>&1 || true)

    assert_contains_stripped "$output" "env-test-namespace" "Should use NAMESPACE env var"
}

test_requires_namespace() {
    local output
    local exit_code

    set +e
    output=$(unset NAMESPACE; "$MANAGE_SCRIPT" status 2>&1)
    exit_code=$?
    set -e

    assert_not_equals "0" "$exit_code" "Should fail without namespace"
    assert_contains_stripped "$output" "Namespace not specified" "Should show namespace error"
}

test_unknown_command() {
    local output
    local exit_code

    set +e
    output=$("$MANAGE_SCRIPT" invalid-command-xyz 2>&1)
    exit_code=$?
    set -e

    assert_not_equals "0" "$exit_code" "Should fail on unknown command"
    assert_contains_stripped "$output" "Unknown command" "Should show unknown command error"
}

test_help_flag() {
    local output
    output=$("$MANAGE_SCRIPT" --help 2>&1)

    assert_contains "$output" "Usage:" "Help flag should show usage"
}

test_version_flag() {
    local output
    output=$("$MANAGE_SCRIPT" --version 2>&1)

    assert_contains "$output" "version" "Version flag should show version"
}

main() {
    start_test_suite "manage.sh Command Tests"

    run_test "manage.sh exists" test_manage_script_exists
    run_test "help command works" test_help_command
    run_test "version command works" test_version_command
    run_test "list-examples command works" test_list_examples_command
    run_test "namespace flag works" test_namespace_flag
    run_test "NAMESPACE env var works" test_namespace_env_var
    run_test "requires namespace for status" test_requires_namespace
    run_test "unknown command fails" test_unknown_command
    run_test "help flag works" test_help_flag
    run_test "version flag works" test_version_flag

    end_test_suite "manage.sh Command Tests"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi