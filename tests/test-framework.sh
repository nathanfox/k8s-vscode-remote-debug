#!/bin/bash

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

VERBOSE="${VERBOSE:-0}"
QUIET="${QUIET:-0}"

TEST_NAMESPACE="${TEST_NAMESPACE:-test-k8s-debug-$(date +%s)}"
TEST_CLEANUP="${TEST_CLEANUP:-1}"

declare -A TEST_RESULTS
declare -A TEST_TIMES

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

start_test_suite() {
    local suite_name="$1"
    echo -e "\n${BLUE}═══ Test Suite: $suite_name ═══${NC}"
    SUITE_START_TIME=$(date +%s)
}

end_test_suite() {
    local suite_name="$1"
    local suite_end_time=$(date +%s)
    local suite_duration=$((suite_end_time - SUITE_START_TIME))

    echo -e "\n${BLUE}═══ Suite Summary: $suite_name ═══${NC}"
    echo "Duration: ${suite_duration}s"
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    [ $TESTS_FAILED -gt 0 ] && echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    [ $TESTS_SKIPPED -gt 0 ] && echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "\n${RED}Failed Tests:${NC}"
        for test_name in "${!TEST_RESULTS[@]}"; do
            if [ "${TEST_RESULTS[$test_name]}" = "FAILED" ]; then
                echo "  - $test_name"
            fi
        done
    fi

    [ $TESTS_FAILED -eq 0 ]
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    local test_start=$(date +%s%N)

    if [ "$QUIET" -eq 0 ]; then
        echo -n "  Testing: $test_name ... "
    fi

    local output_file="/tmp/test-output-$$.txt"
    local error_file="/tmp/test-error-$$.txt"

    if $test_function > "$output_file" 2> "$error_file"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TEST_RESULTS["$test_name"]="PASSED"
        [ "$QUIET" -eq 0 ] && echo -e "${GREEN}✓${NC}"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS["$test_name"]="FAILED"
        [ "$QUIET" -eq 0 ] && echo -e "${RED}✗${NC}"

        if [ "$VERBOSE" -eq 1 ]; then
            echo -e "${RED}    Error output:${NC}"
            cat "$error_file" | sed 's/^/      /'
            if [ -s "$output_file" ]; then
                echo -e "${RED}    Standard output:${NC}"
                cat "$output_file" | sed 's/^/      /'
            fi
        fi
    fi

    local test_end=$(date +%s%N)
    local test_duration=$(( (test_end - test_start) / 1000000 ))
    TEST_TIMES["$test_name"]=$test_duration

    [ "$VERBOSE" -eq 1 ] && echo "    Duration: ${test_duration}ms"

    rm -f "$output_file" "$error_file"
}

skip_test() {
    local test_name="$1"
    local reason="${2:-No reason given}"

    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TEST_RESULTS["$test_name"]="SKIPPED"

    if [ "$QUIET" -eq 0 ]; then
        echo -e "  Testing: $test_name ... ${YELLOW}⊘ SKIPPED${NC} ($reason)"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [ "$expected" != "$actual" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected: '$expected'" >&2
        echo "  Actual:   '$actual'" >&2
        return 1
    fi
    return 0
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    if [ "$unexpected" = "$actual" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Unexpected: '$unexpected'" >&2
        echo "  Actual:     '$actual'" >&2
        return 1
    fi
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  String: '$haystack'" >&2
        echo "  Should contain: '$needle'" >&2
        return 1
    fi
    return 0
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  String: '$haystack'" >&2
        echo "  Should not contain: '$needle'" >&2
        return 1
    fi
    return 0
}

strip_ansi_codes() {
    sed 's/\x1b\[[0-9;]*m//g'
}

assert_contains_stripped() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring (after stripping ANSI codes)}"

    local clean_haystack=$(echo "$haystack" | strip_ansi_codes)

    if [[ ! "$clean_haystack" == *"$needle"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  String (stripped): '$clean_haystack'" >&2
        echo "  Should contain: '$needle'" >&2
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"

    if [ "$expected" -ne "$actual" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected exit code: $expected" >&2
        echo "  Actual exit code:   $actual" >&2
        return 1
    fi
    return 0
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [ ! -f "$file" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File not found: '$file'" >&2
        return 1
    fi
    return 0
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"

    if [ -f "$file" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File exists: '$file'" >&2
        return 1
    fi
    return 0
}

assert_command_exists() {
    local command="$1"
    local message="${2:-Command should exist}"

    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Assertion failed: $message" >&2
        echo "  Command not found: '$command'" >&2
        return 1
    fi
    return 0
}

mock_command() {
    local command="$1"
    local mock_script="$2"

    local mock_dir="${TMPDIR:-/tmp}/mocks-$$"
    mkdir -p "$mock_dir"

    cat > "$mock_dir/$command" << EOF
#!/bin/bash
$mock_script
EOF
    chmod +x "$mock_dir/$command"

    export PATH="$mock_dir:$PATH"
    export MOCK_DIR="$mock_dir"
}

unmock_command() {
    if [ -n "$MOCK_DIR" ]; then
        rm -rf "$MOCK_DIR"
        export PATH="${PATH#$MOCK_DIR:}"
        unset MOCK_DIR
    fi
}

cleanup_test_namespace() {
    if [ "$TEST_CLEANUP" -eq 1 ] && [ -n "$TEST_NAMESPACE" ]; then
        if command -v kubectl >/dev/null 2>&1; then
            kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true >/dev/null 2>&1
        fi
    fi
}

trap cleanup_test_namespace EXIT