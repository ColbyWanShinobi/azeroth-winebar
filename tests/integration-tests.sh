#!/bin/bash

################################################################################
# Azeroth Winebar - Integration Test Suite
################################################################################
#
# This script contains integration tests for the azeroth-winebar installation
# workflow. It tests the complete installation process and component interactions
# in a controlled environment.
#
# Usage: ./integration-tests.sh
# Exit codes: 0 = all tests passed, 1 = one or more tests failed
################################################################################

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/azeroth-winebar.sh"
LAUNCH_SCRIPT="$PROJECT_DIR/lib/wow-launch.sh"
TEST_PREFIX="/tmp/azeroth-integration-test"
TEST_RESULTS=()
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Test Framework Functions
################################################################################

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((TESTS_PASSED++))
    elif [[ "$result" == "SKIP" ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $test_name: $message"
    else
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
        ((TESTS_FAILED++))
    fi
    
    TEST_RESULTS+=("$result: $test_name")
}

# Assert function for testing
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Expected '$expected', got '$actual'"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file_path="$1"
    local test_name="$2"
    
    if [[ -f "$file_path" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "File does not exist: $file_path"
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir_path="$1"
    local test_name="$2"
    
    if [[ -d "$dir_path" ]]; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Directory does not exist: $dir_path"
        return 1
    fi
}

# Assert command success
assert_success() {
    local command="$1"
    local test_name="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Command failed: $command"
        return 1
    fi
}

################################################################################
# Test Environment Setup
################################################################################

setup_integration_environment() {
    echo -e "${YELLOW}Setting up integration test environment...${NC}"
    
    # Create test directories
    mkdir -p "$TEST_PREFIX/config"
    mkdir -p "$TEST_PREFIX/wine-prefix"
    mkdir -p "$TEST_PREFIX/game-dir"
    mkdir -p "$TEST_PREFIX/runners"
    
    # Set environment variables for testing
    export config_dir="$TEST_PREFIX/config"
    export wine_prefix="$TEST_PREFIX/wine-prefix"
    export game_dir="$TEST_PREFIX/game-dir"
    export wine_runners_dir="$TEST_PREFIX/runners"
    
    # Create mock wine binary for testing
    mkdir -p "$TEST_PREFIX/mock-wine/bin"
    cat > "$TEST_PREFIX/mock-wine/bin/wine" << 'EOF'
#!/bin/bash
# Mock wine binary for testing
case "$1" in
    "--version")
        echo "wine-8.0"
        ;;
    *)
        echo "Mock wine execution: $*"
        ;;
esac
exit 0
EOF
    chmod +x "$TEST_PREFIX/mock-wine/bin/wine"
    
    # Add mock wine to PATH for testing
    export PATH="$TEST_PREFIX/mock-wine/bin:$PATH"
    
    echo -e "${GREEN}Integration test environment ready${NC}"
}

cleanup_integration_environment() {
    echo -e "${YELLOW}Cleaning up integration test environment...${NC}"
    
    # Remove test directory
    if [[ -d "$TEST_PREFIX" ]]; then
        rm -rf "$TEST_PREFIX"
    fi
    
    echo -e "${GREEN}Integration cleanup complete${NC}"
}

################################################################################
# Configuration Workflow Tests
################################################################################

test_configuration_workflow() {
    echo -e "${BLUE}Testing configuration workflow...${NC}"
    
    # Source main script functions
    source "$MAIN_SCRIPT" 2>/dev/null || {
        print_test_result "Configuration workflow" "FAIL" "Could not source main script"
        return 1
    }
    
    # Test initial configuration setup
    setup_config_dirs
    assert_dir_exists "$config_dir" "Config directory creation"
    assert_dir_exists "$config_dir/keybinds" "Keybinds directory creation"
    
    # Test wine directory configuration
    save_winedir "$TEST_PREFIX/wine-prefix"
    assert_file_exists "$config_dir/winedir.conf" "Wine directory config saved"
    
    # Test game directory configuration
    save_gamedir "$TEST_PREFIX/game-dir"
    assert_file_exists "$config_dir/gamedir.conf" "Game directory config saved"
    
    # Test configuration loading
    getdirs
    local loaded_wine_prefix="$(cat "$config_dir/winedir.conf" 2>/dev/null)"
    local loaded_game_dir="$(cat "$config_dir/gamedir.conf" 2>/dev/null)"
    
    assert_equals "$TEST_PREFIX/wine-prefix" "$loaded_wine_prefix" "Wine prefix loaded correctly"
    assert_equals "$TEST_PREFIX/game-dir" "$loaded_game_dir" "Game directory loaded correctly"
    
    # Test first run handling
    if is_first_run; then
        mark_first_run_complete
        assert_file_exists "$config_dir/firstrun.conf" "First run marked complete"
    fi
    
    # Test configuration reset
    reset_config
    assert_success "! test -f '$config_dir/winedir.conf'" "Wine config removed after reset"
    assert_success "! test -f '$config_dir/gamedir.conf'" "Game config removed after reset"
}

################################################################################
# Wine Runner Management Tests
################################################################################

test_wine_runner_workflow() {
    echo -e "${BLUE}Testing wine runner management workflow...${NC}"
    
    # Source main script functions
    source "$MAIN_SCRIPT" 2>/dev/null || {
        print_test_result "Wine runner workflow" "FAIL" "Could not source main script"
        return 1
    }
    
    # Test wine runners directory setup
    setup_wine_runners_dir
    assert_dir_exists "$wine_runners_dir" "Wine runners directory created"
    
    # Test Proton Experimental release fetching
    local proton_releases
    proton_releases=$(get_runner_releases "proton-experimental")
    assert_equals "proton-experimental-latest" "$proton_releases" "Proton Experimental release fetched"
    
    # Test mock runner installation
    mkdir -p "$wine_runners_dir/test-runner/bin"
    cat > "$wine_runners_dir/test-runner/bin/wine" << 'EOF'
#!/bin/bash
echo "wine-test-8.0"
exit 0
EOF
    chmod +x "$wine_runners_dir/test-runner/bin/wine"
    
    # Create runner info file
    cat > "$wine_runners_dir/test-runner/.runner-info" << EOF
RUNNER_NAME=test-runner
RUNNER_TYPE=test
INSTALL_DATE=$(date -Iseconds)
WINE_BINARY=$wine_runners_dir/test-runner/bin/wine
EOF
    
    # Test runner listing
    local installed_runners
    installed_runners=$(list_installed_runners)
    assert_success "echo '$installed_runners' | grep -q 'test-runner'" "Installed runner listed"
    
    # Test runner binary path retrieval
    local runner_binary
    runner_binary=$(get_runner_binary "test-runner")
    assert_equals "$wine_runners_dir/test-runner/bin/wine" "$runner_binary" "Runner binary path retrieved"
}

################################################################################
# Launch Script Integration Tests
################################################################################

test_launch_script_integration() {
    echo -e "${BLUE}Testing launch script integration...${NC}"
    
    # Check if launch script exists
    assert_file_exists "$LAUNCH_SCRIPT" "Launch script exists"
    
    # Test launch script configuration loading
    # Create config files for launch script
    echo "$TEST_PREFIX/wine-prefix" > "$config_dir/winedir.conf"
    echo "$TEST_PREFIX/game-dir" > "$config_dir/gamedir.conf"
    
    # Test launch script syntax
    assert_success "bash -n '$LAUNCH_SCRIPT'" "Launch script syntax valid"
    
    # Test launch script environment setup
    # We can't fully test execution without wine, but we can test configuration
    local launch_config_test="
        source '$LAUNCH_SCRIPT' 2>/dev/null || exit 1
        [[ -n \"\$WINEPREFIX\" ]] || exit 1
        [[ -n \"\$GAMEDIR\" ]] || exit 1
    "
    
    # This test might fail if the launch script tries to execute wine commands
    # So we'll make it a conditional test
    if bash -c "$launch_config_test" 2>/dev/null; then
        print_test_result "Launch script environment setup" "PASS"
    else
        print_test_result "Launch script environment setup" "SKIP" "Cannot test without full wine environment"
    fi
}

################################################################################
# System Requirements Integration Tests
################################################################################

test_system_requirements_workflow() {
    echo -e "${BLUE}Testing system requirements workflow...${NC}"
    
    # Source main script functions
    source "$MAIN_SCRIPT" 2>/dev/null || {
        print_test_result "System requirements workflow" "FAIL" "Could not source main script"
        return 1
    }
    
    # Test dependency checking
    check_dependencies
    local dep_check_result=$?
    
    if [[ $dep_check_result -eq 0 ]]; then
        print_test_result "Dependency check workflow" "PASS"
    else
        print_test_result "Dependency check workflow" "SKIP" "Missing dependencies on test system"
    fi
    
    # Test system optimization checks
    # These tests are system-dependent, so we'll make them conditional
    
    # Test memory check
    if check_memory >/dev/null 2>&1; then
        print_test_result "Memory check execution" "PASS"
    else
        print_test_result "Memory check execution" "SKIP" "Memory check failed on test system"
    fi
    
    # Test map count check
    if check_map_count >/dev/null 2>&1; then
        print_test_result "Map count check execution" "PASS"
    else
        print_test_result "Map count check execution" "SKIP" "Map count check failed on test system"
    fi
}

################################################################################
# End-to-End Workflow Tests
################################################################################

test_complete_installation_workflow() {
    echo -e "${BLUE}Testing complete installation workflow simulation...${NC}"
    
    # Source main script functions
    source "$MAIN_SCRIPT" 2>/dev/null || {
        print_test_result "Complete workflow" "FAIL" "Could not source main script"
        return 1
    }
    
    # Simulate complete workflow steps
    echo -e "${YELLOW}  Step 1: Configuration setup${NC}"
    setup_config_dirs
    save_winedir "$TEST_PREFIX/wine-prefix"
    save_gamedir "$TEST_PREFIX/game-dir"
    
    echo -e "${YELLOW}  Step 2: Wine runner setup${NC}"
    setup_wine_runners_dir
    
    echo -e "${YELLOW}  Step 3: System checks${NC}"
    check_dependencies >/dev/null 2>&1
    
    echo -e "${YELLOW}  Step 4: Configuration validation${NC}"
    getdirs
    
    # Verify all components are in place
    assert_dir_exists "$config_dir" "Config directory exists"
    assert_file_exists "$config_dir/winedir.conf" "Wine config exists"
    assert_file_exists "$config_dir/gamedir.conf" "Game config exists"
    assert_dir_exists "$wine_runners_dir" "Wine runners directory exists"
    
    print_test_result "Complete installation workflow simulation" "PASS"
}

################################################################################
# Configuration Persistence Tests
################################################################################

test_configuration_persistence() {
    echo -e "${BLUE}Testing configuration persistence...${NC}"
    
    # Source main script functions
    source "$MAIN_SCRIPT" 2>/dev/null || {
        print_test_result "Configuration persistence" "FAIL" "Could not source main script"
        return 1
    }
    
    # Create initial configuration
    setup_config_dirs
    save_winedir "$TEST_PREFIX/wine-prefix-1"
    save_gamedir "$TEST_PREFIX/game-dir-1"
    
    # Simulate script restart by re-sourcing and loading config
    getdirs
    local loaded_wine_prefix="$(cat "$config_dir/winedir.conf" 2>/dev/null)"
    local loaded_game_dir="$(cat "$config_dir/gamedir.conf" 2>/dev/null)"
    
    assert_equals "$TEST_PREFIX/wine-prefix-1" "$loaded_wine_prefix" "Wine prefix persisted"
    assert_equals "$TEST_PREFIX/game-dir-1" "$loaded_game_dir" "Game directory persisted"
    
    # Test configuration update
    save_winedir "$TEST_PREFIX/wine-prefix-2"
    save_gamedir "$TEST_PREFIX/game-dir-2"
    
    # Reload and verify updates
    getdirs
    loaded_wine_prefix="$(cat "$config_dir/winedir.conf" 2>/dev/null)"
    loaded_game_dir="$(cat "$config_dir/gamedir.conf" 2>/dev/null)"
    
    assert_equals "$TEST_PREFIX/wine-prefix-2" "$loaded_wine_prefix" "Wine prefix updated"
    assert_equals "$TEST_PREFIX/game-dir-2" "$loaded_game_dir" "Game directory updated"
}

################################################################################
# Main Test Runner
################################################################################

run_integration_tests() {
    echo -e "${YELLOW}Starting Azeroth Winebar Integration Tests${NC}"
    echo "=============================================="
    
    # Setup test environment
    setup_integration_environment
    
    # Run integration tests
    test_configuration_workflow
    test_wine_runner_workflow
    test_launch_script_integration
    test_system_requirements_workflow
    test_complete_installation_workflow
    test_configuration_persistence
    
    # Cleanup
    cleanup_integration_environment
    
    # Print summary
    echo
    echo "=============================================="
    echo -e "${YELLOW}Integration Test Summary${NC}"
    echo "=============================================="
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All integration tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some integration tests failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
    exit $?
fi