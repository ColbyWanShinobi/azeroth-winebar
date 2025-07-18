#!/bin/bash

################################################################################
# Azeroth Winebar - Unit Test Suite
################################################################################
#
# This script contains unit tests for core functions in the azeroth-winebar
# script. It tests individual functions in isolation to ensure they work
# correctly with various inputs and edge cases.
#
# Usage: ./unit-tests.sh
# Exit codes: 0 = all tests passed, 1 = one or more tests failed
################################################################################

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/azeroth-winebar.sh"
TEST_CONFIG_DIR="/tmp/azeroth-winebar-test-config"
TEST_RESULTS=()
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Assert command failure
assert_failure() {
    local command="$1"
    local test_name="$2"
    
    if ! eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS"
        return 0
    else
        print_test_result "$test_name" "FAIL" "Command should have failed: $command"
        return 1
    fi
}

################################################################################
# Test Setup and Teardown
################################################################################

setup_test_environment() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Create test config directory
    mkdir -p "$TEST_CONFIG_DIR"
    
    # Source the main script functions (without executing main)
    # We'll mock the config_dir variable for testing
    export config_dir="$TEST_CONFIG_DIR"
    
    # Source functions from main script
    # We need to prevent the main script from executing by setting a flag
    export AZEROTH_TESTING=1
    
    # Save our test config directory before sourcing
    local saved_config_dir="$config_dir"
    
    source "$MAIN_SCRIPT" 2>/dev/null || {
        echo -e "${RED}Error: Could not source main script: $MAIN_SCRIPT${NC}"
        exit 1
    }
    
    # Restore our test config directory after sourcing
    config_dir="$saved_config_dir"
    
    echo -e "${GREEN}Test environment ready${NC}"
}

cleanup_test_environment() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    
    # Remove test config directory
    if [[ -d "$TEST_CONFIG_DIR" ]]; then
        rm -rf "$TEST_CONFIG_DIR"
    fi
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

################################################################################
# Configuration Management Tests
################################################################################

test_setup_config_dirs() {
    echo -e "${YELLOW}Testing configuration directory setup...${NC}"
    
    # Test basic directory creation
    setup_config_dirs
    assert_success "test -d '$TEST_CONFIG_DIR'" "Config directory creation"
    assert_success "test -d '$TEST_CONFIG_DIR/keybinds'" "Keybinds directory creation"
    
    # Test directory permissions
    assert_success "test -r '$TEST_CONFIG_DIR'" "Config directory readable"
    assert_success "test -w '$TEST_CONFIG_DIR'" "Config directory writable"
}

test_save_and_load_winedir() {
    echo -e "${YELLOW}Testing wine directory configuration...${NC}"
    
    local test_winedir="/tmp/test-wine-prefix"
    
    # Test saving wine directory
    save_winedir "$test_winedir"
    assert_success "test -f '$TEST_CONFIG_DIR/winedir.conf'" "Wine directory config file created"
    
    # Test loading wine directory
    local loaded_winedir
    loaded_winedir="$(cat "$TEST_CONFIG_DIR/winedir.conf" 2>/dev/null)"
    assert_equals "$test_winedir" "$loaded_winedir" "Wine directory save/load"
    
    # Test empty parameter handling
    assert_failure "save_winedir ''" "Empty wine directory rejection"
}

test_save_and_load_gamedir() {
    echo -e "${YELLOW}Testing game directory configuration...${NC}"
    
    local test_gamedir="/tmp/test-game-dir"
    
    # Test saving game directory
    save_gamedir "$test_gamedir"
    assert_success "test -f '$TEST_CONFIG_DIR/gamedir.conf'" "Game directory config file created"
    
    # Test loading game directory
    local loaded_gamedir
    loaded_gamedir="$(cat "$TEST_CONFIG_DIR/gamedir.conf" 2>/dev/null)"
    assert_equals "$test_gamedir" "$loaded_gamedir" "Game directory save/load"
    
    # Test empty parameter handling
    assert_failure "save_gamedir ''" "Empty game directory rejection"
}

test_validate_directory() {
    echo -e "${YELLOW}Testing directory validation...${NC}"
    
    # Create test directories
    local valid_dir="/tmp/azeroth-test-valid"
    local invalid_dir="/tmp/azeroth-test-nonexistent"
    
    mkdir -p "$valid_dir"
    
    # Test valid directory
    assert_success "validate_directory '$valid_dir' 'test'" "Valid directory validation"
    
    # Test invalid directory without creation
    assert_failure "validate_directory '$invalid_dir' 'test'" "Invalid directory rejection"
    
    # Test invalid directory with creation
    assert_success "validate_directory '$invalid_dir' 'test' true" "Directory creation on validation"
    assert_success "test -d '$invalid_dir'" "Created directory exists"
    
    # Cleanup
    rm -rf "$valid_dir" "$invalid_dir"
}

test_reset_config() {
    echo -e "${YELLOW}Testing configuration reset...${NC}"
    
    # Create some config files
    echo "test-wine-prefix" > "$TEST_CONFIG_DIR/winedir.conf"
    echo "test-game-dir" > "$TEST_CONFIG_DIR/gamedir.conf"
    echo "completed" > "$TEST_CONFIG_DIR/firstrun.conf"
    
    # Reset configuration
    reset_config
    
    # Verify files are removed
    assert_failure "test -f '$TEST_CONFIG_DIR/winedir.conf'" "Wine directory config removed"
    assert_failure "test -f '$TEST_CONFIG_DIR/gamedir.conf'" "Game directory config removed"
    assert_failure "test -f '$TEST_CONFIG_DIR/firstrun.conf'" "First run config removed"
}

################################################################################
# Dependency Checking Tests
################################################################################

test_command_exists() {
    echo -e "${YELLOW}Testing command existence checking...${NC}"
    
    # Test existing command
    assert_success "command_exists 'bash'" "Existing command detection"
    
    # Test non-existing command
    assert_failure "command_exists 'nonexistent-command-12345'" "Non-existing command detection"
}

################################################################################
# Wine Runner Management Tests
################################################################################

test_setup_wine_runners_dir() {
    echo -e "${YELLOW}Testing wine runners directory setup...${NC}"
    
    # Override wine_runners_dir for testing
    local test_runners_dir="/tmp/azeroth-test-runners"
    wine_runners_dir="$test_runners_dir"
    
    # Test directory creation
    setup_wine_runners_dir
    assert_success "test -d '$test_runners_dir'" "Wine runners directory creation"
    
    # Cleanup
    rm -rf "$test_runners_dir"
}

test_get_runner_releases() {
    echo -e "${YELLOW}Testing wine runner release fetching...${NC}"
    
    # Ensure wine_runner_sources array is properly initialized
    if [[ -z "${wine_runner_sources[proton-experimental]:-}" ]]; then
        # Re-declare the array if it's not loaded properly
        declare -A wine_runner_sources=(
            ["lutris-ge"]="https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases"
            ["lutris-fshack"]="https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases"
            ["wine-tkg"]="https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
            ["proton-ge"]="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
            ["proton-experimental"]="steam://proton-experimental"
        )
    fi
    
    # Test Proton Experimental (special case)
    local proton_releases
    proton_releases=$(get_runner_releases "proton-experimental")
    assert_equals "proton-experimental-latest" "$proton_releases" "Proton Experimental release"
    
    # Test invalid runner type
    assert_failure "get_runner_releases 'invalid-runner-type'" "Invalid runner type rejection"
}

################################################################################
# System Optimization Tests
################################################################################

test_check_map_count() {
    echo -e "${YELLOW}Testing vm.max_map_count checking...${NC}"
    
    # This test checks if the function can read the current value
    # We can't easily test the actual value without root access
    local current_map_count
    if current_map_count=$(cat /proc/sys/vm/max_map_count 2>/dev/null); then
        assert_success "check_map_count" "Map count check function execution"
    else
        print_test_result "Map count check" "SKIP" "Cannot read /proc/sys/vm/max_map_count"
    fi
}

test_check_memory() {
    echo -e "${YELLOW}Testing memory checking...${NC}"
    
    # Test memory check function execution
    # We can't easily test specific values without knowing the system
    assert_success "check_memory" "Memory check function execution"
}

################################################################################
# Message and Menu System Tests
################################################################################

test_debug_print() {
    echo -e "${YELLOW}Testing debug print function...${NC}"
    
    # Test different debug levels
    local output
    
    # Test info level
    output=$(debug_print "info" "Test message" 2>&1)
    assert_success "echo '$output' | grep -q 'Test message'" "Debug print info level"
    
    # Test continue level (should be silent unless debug=1)
    debug=0
    output=$(debug_print "continue" "Debug message" 2>&1)
    assert_equals "" "$output" "Debug print continue level (debug off)"
    
    # Test continue level with debug on
    debug=1
    output=$(debug_print "continue" "Debug message" 2>&1)
    assert_success "echo '$output' | grep -q 'Debug message'" "Debug print continue level (debug on)"
    debug=0
}

################################################################################
# Main Test Runner
################################################################################

run_all_tests() {
    echo -e "${YELLOW}Starting Azeroth Winebar Unit Tests${NC}"
    echo "========================================"
    
    # Setup test environment
    setup_test_environment
    
    # Run configuration tests
    test_setup_config_dirs
    test_save_and_load_winedir
    test_save_and_load_gamedir
    test_validate_directory
    test_reset_config
    
    # Run dependency tests
    test_command_exists
    
    # Run wine runner tests
    test_setup_wine_runners_dir
    test_get_runner_releases
    
    # Run system optimization tests
    test_check_map_count
    test_check_memory
    
    # Run message system tests
    test_debug_print
    
    # Cleanup
    cleanup_test_environment
    
    # Print summary
    echo
    echo "========================================"
    echo -e "${YELLOW}Test Summary${NC}"
    echo "========================================"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Total: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    exit $?
fi