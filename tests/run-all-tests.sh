#!/bin/bash

################################################################################
# Azeroth Winebar - Master Test Runner
################################################################################
#
# This script runs all test suites for the azeroth-winebar project:
# - Unit tests for core functions
# - Integration tests for installation workflow
# - System compatibility tests
#
# Usage: ./run-all-tests.sh [--verbose] [--suite=SUITE]
# Options:
#   --verbose    Show detailed output from all tests
#   --suite=SUITE Run only specific test suite (unit|integration|compatibility)
#
# Exit codes: 0 = all tests passed, 1 = one or more tests failed
################################################################################

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERBOSE=0
SPECIFIC_SUITE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

################################################################################
# Utility Functions
################################################################################

print_header() {
    local title="$1"
    echo
    echo -e "${BOLD}${CYAN}$title${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#title}))${NC}"
}

print_suite_result() {
    local suite_name="$1"
    local result="$2"
    local details="$3"
    
    ((TOTAL_SUITES++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ $suite_name${NC} $details"
        ((PASSED_SUITES++))
    else
        echo -e "${RED}✗ $suite_name${NC} $details"
        ((FAILED_SUITES++))
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --verbose           Show detailed output from all tests"
    echo "  --suite=SUITE       Run only specific test suite"
    echo "                      Valid suites: unit, integration, compatibility, all"
    echo "  --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  Run all test suites"
    echo "  $0 --verbose        Run all tests with detailed output"
    echo "  $0 --suite=unit     Run only unit tests"
    echo "  $0 --suite=integration --verbose"
}

################################################################################
# Test Suite Runners
################################################################################

run_unit_tests() {
    print_header "Running Unit Tests"
    
    local unit_test_script="$SCRIPT_DIR/unit-tests.sh"
    
    if [[ ! -f "$unit_test_script" ]]; then
        print_suite_result "Unit Tests" "FAIL" "(test script not found)"
        return 1
    fi
    
    if [[ ! -x "$unit_test_script" ]]; then
        chmod +x "$unit_test_script"
    fi
    
    local output
    local exit_code
    
    if [[ $VERBOSE -eq 1 ]]; then
        "$unit_test_script"
        exit_code=$?
    else
        output=$("$unit_test_script" 2>&1)
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        local passed_count
        passed_count=$(echo "$output" | grep -c "^\[PASS\]" || echo "0")
        print_suite_result "Unit Tests" "PASS" "($passed_count tests passed)"
        return 0
    else
        local failed_count
        failed_count=$(echo "$output" | grep -c "^\[FAIL\]" || echo "unknown")
        print_suite_result "Unit Tests" "FAIL" "($failed_count tests failed)"
        
        if [[ $VERBOSE -eq 0 ]]; then
            echo -e "${YELLOW}Failed unit tests:${NC}"
            echo "$output" | grep "^\[FAIL\]" | head -5
            if [[ $(echo "$output" | grep -c "^\[FAIL\]") -gt 5 ]]; then
                echo "  ... and more (use --verbose for full output)"
            fi
        fi
        return 1
    fi
}

run_integration_tests() {
    print_header "Running Integration Tests"
    
    local integration_test_script="$SCRIPT_DIR/integration-tests.sh"
    
    if [[ ! -f "$integration_test_script" ]]; then
        print_suite_result "Integration Tests" "FAIL" "(test script not found)"
        return 1
    fi
    
    if [[ ! -x "$integration_test_script" ]]; then
        chmod +x "$integration_test_script"
    fi
    
    local output
    local exit_code
    
    if [[ $VERBOSE -eq 1 ]]; then
        "$integration_test_script"
        exit_code=$?
    else
        output=$("$integration_test_script" 2>&1)
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        local passed_count
        passed_count=$(echo "$output" | grep -c "^\[PASS\]" || echo "0")
        print_suite_result "Integration Tests" "PASS" "($passed_count tests passed)"
        return 0
    else
        local failed_count
        failed_count=$(echo "$output" | grep -c "^\[FAIL\]" || echo "unknown")
        print_suite_result "Integration Tests" "FAIL" "($failed_count tests failed)"
        
        if [[ $VERBOSE -eq 0 ]]; then
            echo -e "${YELLOW}Failed integration tests:${NC}"
            echo "$output" | grep "^\[FAIL\]" | head -5
            if [[ $(echo "$output" | grep -c "^\[FAIL\]") -gt 5 ]]; then
                echo "  ... and more (use --verbose for full output)"
            fi
        fi
        return 1
    fi
}

run_compatibility_tests() {
    print_header "Running System Compatibility Tests"
    
    local compatibility_test_script="$SCRIPT_DIR/system-compatibility-tests.sh"
    
    if [[ ! -f "$compatibility_test_script" ]]; then
        print_suite_result "Compatibility Tests" "FAIL" "(test script not found)"
        return 1
    fi
    
    if [[ ! -x "$compatibility_test_script" ]]; then
        chmod +x "$compatibility_test_script"
    fi
    
    local output
    local exit_code
    
    if [[ $VERBOSE -eq 1 ]]; then
        "$compatibility_test_script"
        exit_code=$?
    else
        output=$("$compatibility_test_script" 2>&1)
        exit_code=$?
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        local passed_count
        passed_count=$(echo "$output" | grep -c "^\[PASS\]" || echo "0")
        print_suite_result "Compatibility Tests" "PASS" "($passed_count checks passed)"
        return 0
    else
        local failed_count
        failed_count=$(echo "$output" | grep -c "^\[FAIL\]" || echo "unknown")
        print_suite_result "Compatibility Tests" "FAIL" "($failed_count checks failed)"
        
        if [[ $VERBOSE -eq 0 ]]; then
            echo -e "${YELLOW}Failed compatibility checks:${NC}"
            echo "$output" | grep "^\[FAIL\]" | head -5
            if [[ $(echo "$output" | grep -c "^\[FAIL\]") -gt 5 ]]; then
                echo "  ... and more (use --verbose for full output)"
            fi
        fi
        return 1
    fi
}

################################################################################
# Argument Processing
################################################################################

process_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=1
                shift
                ;;
            --suite=*)
                SPECIFIC_SUITE="${1#*=}"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate suite selection
    if [[ -n "$SPECIFIC_SUITE" ]]; then
        case "$SPECIFIC_SUITE" in
            unit|integration|compatibility|all)
                ;;
            *)
                echo -e "${RED}Error: Invalid suite '$SPECIFIC_SUITE'${NC}"
                echo "Valid suites: unit, integration, compatibility, all"
                exit 1
                ;;
        esac
    fi
}

################################################################################
# Main Test Runner
################################################################################

run_selected_tests() {
    local suite_selection="${SPECIFIC_SUITE:-all}"
    local overall_result=0
    
    case "$suite_selection" in
        unit)
            run_unit_tests || overall_result=1
            ;;
        integration)
            run_integration_tests || overall_result=1
            ;;
        compatibility)
            run_compatibility_tests || overall_result=1
            ;;
        all)
            run_unit_tests || overall_result=1
            run_integration_tests || overall_result=1
            run_compatibility_tests || overall_result=1
            ;;
    esac
    
    return $overall_result
}

print_final_summary() {
    print_header "Test Summary"
    
    echo -e "${BOLD}Results:${NC}"
    echo -e "  ${GREEN}Passed suites: $PASSED_SUITES${NC}"
    echo -e "  ${RED}Failed suites: $FAILED_SUITES${NC}"
    echo -e "  Total suites: $TOTAL_SUITES"
    echo
    
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${BOLD}${GREEN}🎉 All test suites passed!${NC}"
        echo -e "${GREEN}The azeroth-winebar project is ready for use.${NC}"
    else
        echo -e "${BOLD}${RED}❌ Some test suites failed!${NC}"
        echo -e "${RED}Please review the failed tests before using azeroth-winebar.${NC}"
        echo
        echo -e "${YELLOW}Troubleshooting tips:${NC}"
        echo -e "  • Run with --verbose to see detailed error messages"
        echo -e "  • Check system requirements and dependencies"
        echo -e "  • Ensure proper permissions for test execution"
        echo -e "  • Review individual test suite outputs"
    fi
}

main() {
    # Process command line arguments
    process_arguments "$@"
    
    # Print header
    echo -e "${BOLD}${BLUE}Azeroth Winebar - Test Suite Runner${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo
    
    # Show configuration
    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  Project directory: $PROJECT_DIR"
    echo -e "  Test directory: $SCRIPT_DIR"
    echo -e "  Verbose output: $([ $VERBOSE -eq 1 ] && echo "enabled" || echo "disabled")"
    echo -e "  Test suite: ${SPECIFIC_SUITE:-all}"
    
    # Run selected tests
    local test_result
    run_selected_tests
    test_result=$?
    
    # Print final summary
    print_final_summary
    
    # Exit with appropriate code
    exit $test_result
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi