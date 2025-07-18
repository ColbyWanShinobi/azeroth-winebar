#!/bin/bash

################################################################################
# Azeroth Winebar - System Compatibility Test Suite
################################################################################
#
# This script tests system compatibility for the azeroth-winebar across
# different Linux distributions, desktop environments, and hardware
# configurations.
#
# Usage: ./system-compatibility-tests.sh
# Exit codes: 0 = all tests passed, 1 = one or more tests failed
################################################################################

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_SCRIPT="$PROJECT_DIR/azeroth-winebar.sh"
TEST_RESULTS=()
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Test Framework Functions
################################################################################

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    case "$result" in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $test_name"
            ((TESTS_PASSED++))
            ;;
        "SKIP")
            echo -e "${YELLOW}[SKIP]${NC} $test_name: $message"
            ((TESTS_SKIPPED++))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $test_name: $message"
            ((TESTS_FAILED++))
            ;;
        "INFO")
            echo -e "${CYAN}[INFO]${NC} $test_name: $message"
            ;;
    esac
    
    TEST_RESULTS+=("$result: $test_name")
}

# Detect system information
detect_system_info() {
    echo -e "${BLUE}Detecting system information...${NC}"
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_NAME="$NAME"
        DISTRO_VERSION="$VERSION"
        DISTRO_ID="$ID"
    else
        DISTRO_NAME="Unknown"
        DISTRO_VERSION="Unknown"
        DISTRO_ID="unknown"
    fi
    
    # Detect desktop environment
    DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
    if [[ -z "$DESKTOP_ENV" ]]; then
        DESKTOP_ENV="$DESKTOP_SESSION"
    fi
    if [[ -z "$DESKTOP_ENV" ]]; then
        DESKTOP_ENV="Unknown"
    fi
    
    # Detect hardware
    CPU_INFO="$(grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | xargs)"
    MEMORY_GB="$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))"
    
    # Detect graphics
    GPU_INFO="$(lspci | grep -i vga | head -1 | cut -d':' -f3 | xargs)"
    if [[ -z "$GPU_INFO" ]]; then
        GPU_INFO="$(lspci | grep -i '3d\|display' | head -1 | cut -d':' -f3 | xargs)"
    fi
    
    # Print system information
    print_test_result "Distribution" "INFO" "$DISTRO_NAME $DISTRO_VERSION ($DISTRO_ID)"
    print_test_result "Desktop Environment" "INFO" "$DESKTOP_ENV"
    print_test_result "CPU" "INFO" "$CPU_INFO"
    print_test_result "Memory" "INFO" "${MEMORY_GB}GB"
    print_test_result "Graphics" "INFO" "$GPU_INFO"
}

################################################################################
# Distribution Compatibility Tests
################################################################################

test_distribution_compatibility() {
    echo -e "${BLUE}Testing distribution compatibility...${NC}"
    
    # Test package manager availability
    local package_managers=("apt" "yum" "dnf" "pacman" "zypper" "emerge")
    local found_pm=""
    
    for pm in "${package_managers[@]}"; do
        if command -v "$pm" >/dev/null 2>&1; then
            found_pm="$pm"
            break
        fi
    done
    
    if [[ -n "$found_pm" ]]; then
        print_test_result "Package manager detection" "PASS" "Found: $found_pm"
    else
        print_test_result "Package manager detection" "FAIL" "No supported package manager found"
    fi
    
    # Test distribution-specific features
    case "$DISTRO_ID" in
        "ubuntu"|"debian")
            test_debian_based_compatibility
            ;;
        "fedora"|"rhel"|"centos")
            test_redhat_based_compatibility
            ;;
        "arch"|"manjaro")
            test_arch_based_compatibility
            ;;
        "opensuse"|"sles")
            test_suse_based_compatibility
            ;;
        *)
            print_test_result "Distribution-specific tests" "SKIP" "Unknown distribution: $DISTRO_ID"
            ;;
    esac
}

test_debian_based_compatibility() {
    echo -e "${YELLOW}  Testing Debian-based distribution compatibility...${NC}"
    
    # Test APT availability
    if command -v apt >/dev/null 2>&1; then
        print_test_result "APT package manager" "PASS"
    else
        print_test_result "APT package manager" "FAIL" "APT not available"
    fi
    
    # Test common package availability
    local packages=("curl" "unzip" "cabextract")
    for package in "${packages[@]}"; do
        if dpkg -l "$package" >/dev/null 2>&1 || command -v "$package" >/dev/null 2>&1; then
            print_test_result "Package: $package" "PASS"
        else
            print_test_result "Package: $package" "SKIP" "Not installed (can be installed via apt)"
        fi
    done
}

test_redhat_based_compatibility() {
    echo -e "${YELLOW}  Testing Red Hat-based distribution compatibility...${NC}"
    
    # Test DNF/YUM availability
    if command -v dnf >/dev/null 2>&1; then
        print_test_result "DNF package manager" "PASS"
    elif command -v yum >/dev/null 2>&1; then
        print_test_result "YUM package manager" "PASS"
    else
        print_test_result "Package manager" "FAIL" "Neither DNF nor YUM available"
    fi
    
    # Test EPEL availability (for RHEL/CentOS)
    if [[ "$DISTRO_ID" == "rhel" || "$DISTRO_ID" == "centos" ]]; then
        if rpm -q epel-release >/dev/null 2>&1; then
            print_test_result "EPEL repository" "PASS"
        else
            print_test_result "EPEL repository" "SKIP" "Not installed (recommended for additional packages)"
        fi
    fi
}

test_arch_based_compatibility() {
    echo -e "${YELLOW}  Testing Arch-based distribution compatibility...${NC}"
    
    # Test Pacman availability
    if command -v pacman >/dev/null 2>&1; then
        print_test_result "Pacman package manager" "PASS"
    else
        print_test_result "Pacman package manager" "FAIL" "Pacman not available"
    fi
    
    # Test AUR helper availability
    local aur_helpers=("yay" "paru" "trizen")
    local found_aur=""
    
    for helper in "${aur_helpers[@]}"; do
        if command -v "$helper" >/dev/null 2>&1; then
            found_aur="$helper"
            break
        fi
    done
    
    if [[ -n "$found_aur" ]]; then
        print_test_result "AUR helper" "PASS" "Found: $found_aur"
    else
        print_test_result "AUR helper" "SKIP" "No AUR helper found (optional)"
    fi
}

test_suse_based_compatibility() {
    echo -e "${YELLOW}  Testing SUSE-based distribution compatibility...${NC}"
    
    # Test Zypper availability
    if command -v zypper >/dev/null 2>&1; then
        print_test_result "Zypper package manager" "PASS"
    else
        print_test_result "Zypper package manager" "FAIL" "Zypper not available"
    fi
}

################################################################################
# Desktop Environment Compatibility Tests
################################################################################

test_desktop_environment_compatibility() {
    echo -e "${BLUE}Testing desktop environment compatibility...${NC}"
    
    # Test GUI availability
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        print_test_result "GUI environment" "PASS" "Display server available"
    else
        print_test_result "GUI environment" "SKIP" "No display server (terminal mode only)"
    fi
    
    # Test Zenity availability for GUI dialogs
    if command -v zenity >/dev/null 2>&1; then
        print_test_result "Zenity GUI dialogs" "PASS"
        
        # Test Zenity functionality (if GUI available)
        if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
            if timeout 2 zenity --info --text="Test" --no-wrap 2>/dev/null; then
                print_test_result "Zenity functionality" "PASS"
            else
                print_test_result "Zenity functionality" "SKIP" "Cannot test GUI in current environment"
            fi
        fi
    else
        print_test_result "Zenity GUI dialogs" "SKIP" "Not installed (terminal mode will be used)"
    fi
    
    # Test desktop-specific features
    case "$DESKTOP_ENV" in
        *"GNOME"*|*"gnome"*)
            test_gnome_compatibility
            ;;
        *"KDE"*|*"kde"*|*"plasma"*)
            test_kde_compatibility
            ;;
        *"XFCE"*|*"xfce"*)
            test_xfce_compatibility
            ;;
        *)
            print_test_result "Desktop-specific tests" "SKIP" "Unknown or unsupported desktop: $DESKTOP_ENV"
            ;;
    esac
}

test_gnome_compatibility() {
    echo -e "${YELLOW}  Testing GNOME compatibility...${NC}"
    
    # Test GNOME-specific tools
    if command -v gnome-terminal >/dev/null 2>&1; then
        print_test_result "GNOME Terminal" "PASS"
    else
        print_test_result "GNOME Terminal" "SKIP" "Not available"
    fi
    
    # Test desktop file handling
    local desktop_dir="$HOME/.local/share/applications"
    if [[ -d "$desktop_dir" ]]; then
        print_test_result "Desktop applications directory" "PASS"
    else
        print_test_result "Desktop applications directory" "SKIP" "Directory not found"
    fi
}

test_kde_compatibility() {
    echo -e "${YELLOW}  Testing KDE compatibility...${NC}"
    
    # Test KDE-specific tools
    if command -v konsole >/dev/null 2>&1; then
        print_test_result "Konsole Terminal" "PASS"
    else
        print_test_result "Konsole Terminal" "SKIP" "Not available"
    fi
    
    # Test KDialog availability as Zenity alternative
    if command -v kdialog >/dev/null 2>&1; then
        print_test_result "KDialog" "PASS" "Available as Zenity alternative"
    else
        print_test_result "KDialog" "SKIP" "Not available"
    fi
}

test_xfce_compatibility() {
    echo -e "${YELLOW}  Testing XFCE compatibility...${NC}"
    
    # Test XFCE-specific tools
    if command -v xfce4-terminal >/dev/null 2>&1; then
        print_test_result "XFCE Terminal" "PASS"
    else
        print_test_result "XFCE Terminal" "SKIP" "Not available"
    fi
}

################################################################################
# Hardware Compatibility Tests
################################################################################

test_hardware_compatibility() {
    echo -e "${BLUE}Testing hardware compatibility...${NC}"
    
    # Test memory requirements
    if [[ $MEMORY_GB -ge 16 ]]; then
        print_test_result "Memory requirement (16GB+)" "PASS" "${MEMORY_GB}GB available"
    elif [[ $MEMORY_GB -ge 8 ]]; then
        print_test_result "Memory requirement (16GB+)" "SKIP" "${MEMORY_GB}GB available (minimum for basic functionality)"
    else
        print_test_result "Memory requirement (16GB+)" "FAIL" "Only ${MEMORY_GB}GB available"
    fi
    
    # Test graphics compatibility
    test_graphics_compatibility
    
    # Test CPU architecture
    local cpu_arch
    cpu_arch="$(uname -m)"
    case "$cpu_arch" in
        "x86_64"|"amd64")
            print_test_result "CPU architecture" "PASS" "64-bit ($cpu_arch)"
            ;;
        "i386"|"i686")
            print_test_result "CPU architecture" "FAIL" "32-bit not supported ($cpu_arch)"
            ;;
        *)
            print_test_result "CPU architecture" "SKIP" "Unknown architecture ($cpu_arch)"
            ;;
    esac
    
    # Test available disk space
    local available_space
    available_space="$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')"
    if [[ $available_space -ge 50 ]]; then
        print_test_result "Disk space" "PASS" "${available_space}GB available"
    elif [[ $available_space -ge 20 ]]; then
        print_test_result "Disk space" "SKIP" "${available_space}GB available (minimum for basic installation)"
    else
        print_test_result "Disk space" "FAIL" "Only ${available_space}GB available"
    fi
}

test_graphics_compatibility() {
    echo -e "${YELLOW}  Testing graphics compatibility...${NC}"
    
    # Test for NVIDIA graphics
    if echo "$GPU_INFO" | grep -qi nvidia; then
        print_test_result "NVIDIA GPU detected" "INFO" "$GPU_INFO"
        
        # Test NVIDIA driver
        if command -v nvidia-smi >/dev/null 2>&1; then
            local nvidia_version
            nvidia_version="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1)"
            print_test_result "NVIDIA driver" "PASS" "Version: $nvidia_version"
        else
            print_test_result "NVIDIA driver" "SKIP" "nvidia-smi not available"
        fi
        
        # Test Vulkan support
        if command -v vulkaninfo >/dev/null 2>&1; then
            if vulkaninfo >/dev/null 2>&1; then
                print_test_result "Vulkan support" "PASS"
            else
                print_test_result "Vulkan support" "FAIL" "Vulkan not working"
            fi
        else
            print_test_result "Vulkan support" "SKIP" "vulkaninfo not available"
        fi
    fi
    
    # Test for AMD graphics
    if echo "$GPU_INFO" | grep -qi amd; then
        print_test_result "AMD GPU detected" "INFO" "$GPU_INFO"
        
        # Test Mesa driver
        if command -v glxinfo >/dev/null 2>&1; then
            local mesa_version
            mesa_version="$(glxinfo | grep -i "mesa" | head -1 | cut -d' ' -f2-)"
            if [[ -n "$mesa_version" ]]; then
                print_test_result "Mesa driver" "PASS" "$mesa_version"
            else
                print_test_result "Mesa driver" "SKIP" "Mesa version not detected"
            fi
        else
            print_test_result "Mesa driver" "SKIP" "glxinfo not available"
        fi
    fi
    
    # Test for Intel graphics
    if echo "$GPU_INFO" | grep -qi intel; then
        print_test_result "Intel GPU detected" "INFO" "$GPU_INFO"
    fi
}

################################################################################
# Wine Compatibility Tests
################################################################################

test_wine_compatibility() {
    echo -e "${BLUE}Testing Wine compatibility...${NC}"
    
    # Test Wine installation
    if command -v wine >/dev/null 2>&1; then
        local wine_version
        wine_version="$(wine --version 2>/dev/null)"
        print_test_result "Wine installation" "PASS" "$wine_version"
        
        # Test Wine architecture support
        if wine --version | grep -q "64"; then
            print_test_result "Wine 64-bit support" "PASS"
        else
            print_test_result "Wine 64-bit support" "SKIP" "Cannot determine from version string"
        fi
        
        # Test Winetricks
        if command -v winetricks >/dev/null 2>&1; then
            print_test_result "Winetricks" "PASS"
        else
            print_test_result "Winetricks" "SKIP" "Not installed (recommended)"
        fi
    else
        print_test_result "Wine installation" "SKIP" "Wine not installed"
    fi
    
    # Test for Steam (for Proton Experimental)
    if command -v steam >/dev/null 2>&1; then
        print_test_result "Steam installation" "PASS"
        
        # Check for Steam directory
        local steam_dirs=(
            "$HOME/.steam/steam"
            "$HOME/.local/share/Steam"
            "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        )
        
        local found_steam_dir=""
        for steam_dir in "${steam_dirs[@]}"; do
            if [[ -d "$steam_dir" ]]; then
                found_steam_dir="$steam_dir"
                break
            fi
        done
        
        if [[ -n "$found_steam_dir" ]]; then
            print_test_result "Steam directory" "PASS" "$found_steam_dir"
        else
            print_test_result "Steam directory" "SKIP" "Steam directory not found"
        fi
    else
        print_test_result "Steam installation" "SKIP" "Steam not installed (needed for Proton Experimental)"
    fi
}

################################################################################
# System Optimization Tests
################################################################################

test_system_optimization_compatibility() {
    echo -e "${BLUE}Testing system optimization compatibility...${NC}"
    
    # Test vm.max_map_count
    local current_map_count
    if current_map_count="$(cat /proc/sys/vm/max_map_count 2>/dev/null)"; then
        if [[ $current_map_count -ge 16777216 ]]; then
            print_test_result "vm.max_map_count" "PASS" "Current: $current_map_count"
        else
            print_test_result "vm.max_map_count" "SKIP" "Current: $current_map_count (needs optimization)"
        fi
    else
        print_test_result "vm.max_map_count" "FAIL" "Cannot read /proc/sys/vm/max_map_count"
    fi
    
    # Test file descriptor limits
    local soft_limit hard_limit
    soft_limit="$(ulimit -Sn)"
    hard_limit="$(ulimit -Hn)"
    
    if [[ $hard_limit -ge 524288 ]]; then
        print_test_result "File descriptor limit" "PASS" "Hard limit: $hard_limit"
    else
        print_test_result "File descriptor limit" "SKIP" "Hard limit: $hard_limit (needs optimization)"
    fi
    
    # Test for systemd (for persistent optimizations)
    if command -v systemctl >/dev/null 2>&1; then
        print_test_result "Systemd" "PASS" "Available for persistent optimizations"
    else
        print_test_result "Systemd" "SKIP" "Not available (alternative methods needed)"
    fi
    
    # Test for polkit (for privilege escalation)
    if command -v pkexec >/dev/null 2>&1; then
        print_test_result "PolicyKit" "PASS" "Available for privilege escalation"
    elif command -v sudo >/dev/null 2>&1; then
        print_test_result "Sudo" "PASS" "Available for privilege escalation"
    else
        print_test_result "Privilege escalation" "SKIP" "No polkit or sudo available"
    fi
}

################################################################################
# Main Test Runner
################################################################################

run_system_compatibility_tests() {
    echo -e "${YELLOW}Starting Azeroth Winebar System Compatibility Tests${NC}"
    echo "====================================================="
    
    # Detect system information
    detect_system_info
    echo
    
    # Run compatibility tests
    test_distribution_compatibility
    echo
    test_desktop_environment_compatibility
    echo
    test_hardware_compatibility
    echo
    test_wine_compatibility
    echo
    test_system_optimization_compatibility
    
    # Print summary
    echo
    echo "====================================================="
    echo -e "${YELLOW}System Compatibility Test Summary${NC}"
    echo "====================================================="
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "Total: $((TESTS_PASSED + TESTS_SKIPPED + TESTS_FAILED))"
    
    # Provide recommendations based on results
    echo
    echo -e "${CYAN}Recommendations:${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}• Address failed tests before using azeroth-winebar${NC}"
    fi
    if [[ $TESTS_SKIPPED -gt 5 ]]; then
        echo -e "${YELLOW}• Consider installing optional dependencies for better functionality${NC}"
    fi
    if [[ $TESTS_PASSED -gt $((TESTS_FAILED + TESTS_SKIPPED)) ]]; then
        echo -e "${GREEN}• System appears compatible with azeroth-winebar${NC}"
    fi
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}System compatibility check completed successfully!${NC}"
        return 0
    else
        echo -e "${RED}System compatibility issues detected!${NC}"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_system_compatibility_tests
    exit $?
fi