# K8s Remote Debugging - Test Suite

Automated testing framework for the K8s remote debugging examples repository.

## Test Structure

```
tests/
├── test-framework.sh           # Core testing framework with assertions
├── run-tests.sh               # Main test runner
├── unit/                      # Unit tests
│   └── test-manage-commands.sh
├── integration/               # Integration tests (future)
├── fixtures/                  # Test fixtures and data
└── reports/                   # Test reports (generated)
```

## Running Tests

### Quick Tests
```bash
# Run basic smoke tests
./tests/run-tests.sh quick
```

### Unit Tests
```bash
# Test management scripts and functions
./tests/run-tests.sh unit
```

### Integration Tests
```bash
# Test with actual K8s cluster (future)
./tests/run-tests.sh integration
```

### All Tests
```bash
# Run complete test suite
./tests/run-tests.sh all
```

### Specific Test File
```bash
# Run a specific test file
./tests/run-tests.sh specific tests/unit/test-manage-commands.sh
```

## Test Framework Features

### Assertions
- `assert_equals` - Check values are equal
- `assert_not_equals` - Check values are not equal
- `assert_contains` - Check string contains substring
- `assert_contains_stripped` - Check with ANSI colors stripped
- `assert_not_contains` - Check string doesn't contain substring
- `assert_exit_code` - Check command exit code
- `assert_file_exists` - Check file exists
- `assert_file_not_exists` - Check file doesn't exist
- `assert_command_exists` - Check command is available

### Test Control
- `run_test` - Execute a test function
- `skip_test` - Skip a test with reason
- `mock_command` - Create command mock for testing
- `unmock_command` - Remove command mock

### Environment Variables
- `VERBOSE=1` - Show detailed test output
- `QUIET=1` - Suppress most output
- `TEST_CLEANUP=0` - Skip test namespace cleanup
- `TEST_NAMESPACE` - Override test namespace name

## Test Coverage

### Unit Tests
- **Management Commands**
  - Help and version commands
  - Namespace handling (flag and env var)
  - Command existence validation
  - Option parsing
  - Error handling

### Integration Tests (Planned)
- Kubernetes namespace operations
- Example deployment workflows
- Debugging setup (port-forward)
- Multi-example deployment

## Writing New Tests

1. Create test file in appropriate directory:
```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../test-framework.sh"

test_my_feature() {
    local output
    output=$(my_command 2>&1)

    assert_contains "$output" "expected" "Should contain expected text"
}

main() {
    start_test_suite "My Feature Tests"
    run_test "Feature works" test_my_feature
    end_test_suite "My Feature Tests"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
```

2. Make executable:
```bash
chmod +x tests/unit/test-my-feature.sh
```

3. Run tests:
```bash
./tests/run-tests.sh specific tests/unit/test-my-feature.sh
```

## Example Usage

```bash
# Run tests with verbose output
VERBOSE=1 ./tests/run-tests.sh unit

# Run tests quietly
QUIET=1 ./tests/run-tests.sh all

# Keep test namespace after run
TEST_CLEANUP=0 ./tests/run-tests.sh integration
```

## CI/CD Integration

For CI/CD pipelines:
```yaml
# Example GitHub Actions
- name: Run Tests
  run: |
    export TEST_NAMESPACE=ci-test-${{ github.run_id }}
    ./tests/run-tests.sh quick
    ./tests/run-tests.sh unit
```

## Current Status

🚧 **In Development** - Basic test framework and unit tests in place.

- ✅ Test framework with assertions
- ✅ Test runner with multiple modes
- ✅ Basic unit tests for manage.sh
- 📋 Integration tests (planned)
- 📋 Example-specific tests (planned)

## Future Enhancements

- [ ] Integration tests with actual K8s cluster
- [ ] Per-example test suites
- [ ] Docker image build tests
- [ ] VS Code configuration validation
- [ ] End-to-end debugging workflow tests
- [ ] JSON test report generation
- [ ] Test coverage metrics

## Troubleshooting

### Tests Failing with Color Codes
Use `assert_contains_stripped` instead of `assert_contains` for colored output.

### Kubectl Tests Fail
Ensure kubectl is configured and you have access to a test cluster.

### Permission Errors
Ensure test scripts are executable:
```bash
chmod +x tests/*.sh tests/**/*.sh
```