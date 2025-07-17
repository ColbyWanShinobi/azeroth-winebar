#!/bin/bash

############################################################################
# Azeroth Winebar - World of Warcraft Helper Script for Linux
############################################################################
#
# Author: Azeroth Winebar Project
# Description: A helper script for managing and optimizing World of Warcraft
#              and Battle.net on Linux systems using wine/Proton Experimental
#
# This script is based on the lug-helper project but adapted specifically
# for Blizzard's Battle.net launcher and World of Warcraft
#
# License: GPL-3.0
############################################################################

# Script version
script_version="1.0.0"
script_name="Azeroth Winebar"

# Global variables
wine_prefix=""
game_dir=""
config_dir="$HOME/.config/azeroth-winebar"
debug=0
gui_zenity=0

# Required dependencies
dependencies=("bash" "curl" "unzip")
optional_dependencies=("zenity" "cabextract" "polkit")

############################################################################
# Configuration and Directory Management
############################################################################

# Create configuration directory structure
setup_config_dirs() {
    debug_print continue "Setting up configuration directories..."
    
    # Create main config directory
    if [[ ! -d "$config_dir" ]]; then
        if ! mkdir -p "$config_dir"; then
            debug_print exit "Failed to create config directory: $config_dir"
            return 1
        fi
    fi
    
    # Create keybinds backup directory
    if [[ ! -d "$config_dir/keybinds" ]]; then
        if ! mkdir -p "$config_dir/keybinds"; then
            debug_print exit "Failed to create keybinds directory: $config_dir/keybinds"
            return 1
        fi
    fi
    
    debug_print continue "Configuration directories created successfully"
    return 0
}

# Get wine prefix and game directories from config files
getdirs() {
    debug_print continue "Loading directory configuration..."
    
    # Load wine prefix directory
    if [[ -f "$config_dir/winedir.conf" ]]; then
        wine_prefix="$(cat "$config_dir/winedir.conf" 2>/dev/null)"
        if [[ -z "$wine_prefix" ]]; then
            debug_print continue "Wine prefix config file is empty"
        else
            debug_print continue "Wine prefix loaded: $wine_prefix"
        fi
    else
        debug_print continue "No wine prefix configured"
    fi
    
    # Load game directory
    if [[ -f "$config_dir/gamedir.conf" ]]; then
        game_dir="$(cat "$config_dir/gamedir.conf" 2>/dev/null)"
        if [[ -z "$game_dir" ]]; then
            debug_print continue "Game directory config file is empty"
        else
            debug_print continue "Game directory loaded: $game_dir"
        fi
    else
        debug_print continue "No game directory configured"
    fi
    
    # Validate directories exist if they're set
    if [[ -n "$wine_prefix" ]]; then
        if [[ ! -d "$wine_prefix" ]]; then
            debug_print continue "Warning: Wine prefix directory does not exist: $wine_prefix"
            return 1
        elif [[ ! -r "$wine_prefix" || ! -w "$wine_prefix" ]]; then
            debug_print continue "Warning: Wine prefix directory is not accessible: $wine_prefix"
            return 1
        fi
    fi
    
    if [[ -n "$game_dir" ]]; then
        if [[ ! -d "$game_dir" ]]; then
            debug_print continue "Warning: Game directory does not exist: $game_dir"
            return 1
        elif [[ ! -r "$game_dir" ]]; then
            debug_print continue "Warning: Game directory is not readable: $game_dir"
            return 1
        fi
    fi
    
    return 0
}

# Save wine prefix directory to config
save_winedir() {
    local winedir="$1"
    
    if [[ -z "$winedir" ]]; then
        debug_print exit "No wine directory specified"
        return 1
    fi
    
    if echo "$winedir" > "$config_dir/winedir.conf"; then
        wine_prefix="$winedir"
        debug_print continue "Wine prefix saved: $winedir"
        return 0
    else
        debug_print exit "Failed to save wine prefix configuration"
        return 1
    fi
}

# Save game directory to config
save_gamedir() {
    local gamedir="$1"
    
    if [[ -z "$gamedir" ]]; then
        debug_print exit "No game directory specified"
        return 1
    fi
    
    if echo "$gamedir" > "$config_dir/gamedir.conf"; then
        game_dir="$gamedir"
        debug_print continue "Game directory saved: $gamedir"
        return 0
    else
        debug_print exit "Failed to save game directory configuration"
        return 1
    fi
}

# Validate directory path and permissions
validate_directory() {
    local dir_path="$1"
    local dir_type="$2"
    local create_if_missing="${3:-false}"
    
    if [[ -z "$dir_path" ]]; then
        debug_print exit "No directory path specified for validation"
        return 1
    fi
    
    # Check if directory exists
    if [[ ! -d "$dir_path" ]]; then
        if [[ "$create_if_missing" == "true" ]]; then
            debug_print continue "Creating missing $dir_type directory: $dir_path"
            if ! mkdir -p "$dir_path"; then
                debug_print exit "Failed to create $dir_type directory: $dir_path"
                return 1
            fi
        else
            debug_print exit "$dir_type directory does not exist: $dir_path"
            return 1
        fi
    fi
    
    # Check read permissions
    if [[ ! -r "$dir_path" ]]; then
        debug_print exit "$dir_type directory is not readable: $dir_path"
        return 1
    fi
    
    # Check write permissions for wine prefix
    if [[ "$dir_type" == "wine prefix" && ! -w "$dir_path" ]]; then
        debug_print exit "$dir_type directory is not writable: $dir_path"
        return 1
    fi
    
    debug_print continue "$dir_type directory validation successful: $dir_path"
    return 0
}

# Reset configuration to defaults
reset_config() {
    debug_print continue "Resetting configuration to defaults..."
    
    # Clear global variables
    wine_prefix=""
    game_dir=""
    
    # Remove config files
    local config_files=("winedir.conf" "gamedir.conf" "firstrun.conf")
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_dir/$config_file" ]]; then
            if rm "$config_dir/$config_file"; then
                debug_print continue "Removed config file: $config_file"
            else
                debug_print continue "Warning: Failed to remove config file: $config_file"
            fi
        fi
    done
    
    debug_print continue "Configuration reset completed"
    return 0
}

# Check if this is the first run
is_first_run() {
    if [[ ! -f "$config_dir/firstrun.conf" ]]; then
        return 0  # First run
    else
        return 1  # Not first run
    fi
}

# Mark first run as completed
mark_first_run_complete() {
    if echo "completed" > "$config_dir/firstrun.conf"; then
        debug_print continue "First run marked as completed"
        return 0
    else
        debug_print continue "Warning: Failed to mark first run as completed"
        return 1
    fi
}

############################################################################
# Dependency Checking Functions
############################################################################

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required dependencies
check_dependencies() {
    debug_print continue "Checking required dependencies..."
    
    local missing_deps=()
    local missing_optional=()
    
    # Check required dependencies
    for dep in "${dependencies[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
            debug_print continue "Missing required dependency: $dep"
        fi
    done
    
    # Check optional dependencies
    for dep in "${optional_dependencies[@]}"; do
        if ! command_exists "$dep"; then
            missing_optional+=("$dep")
            debug_print continue "Missing optional dependency: $dep"
        fi
    done
    
    # Report results
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        debug_print exit "Missing required dependencies: ${missing_deps[*]}"
        message error "Missing Required Dependencies" "The following required packages are missing:\n\n${missing_deps[*]}\n\nPlease install them using your distribution's package manager."
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        debug_print continue "Missing optional dependencies: ${missing_optional[*]}"
        message info "Optional Dependencies" "The following optional packages are missing:\n\n${missing_optional[*]}\n\nInstalling them will enable additional features like GUI dialogs."
    fi
    
    # Set GUI availability
    if command_exists "zenity"; then
        gui_zenity=1
        debug_print continue "Zenity GUI available"
    else
        debug_print continue "Zenity GUI not available, using terminal interface"
    fi
    
    debug_print continue "Dependency check completed successfully"
    return 0
}

# Check wine installation and version
check_wine() {
    debug_print continue "Checking wine installation..."
    
    if ! command_exists "wine"; then
        debug_print exit "Wine is not installed"
        message error "Wine Not Found" "Wine is required but not installed.\n\nPlease install wine or use the wine runner management feature."
        return 1
    fi
    
    local wine_version
    wine_version="$(wine --version 2>/dev/null)"
    
    if [[ -z "$wine_version" ]]; then
        debug_print exit "Failed to get wine version"
        return 1
    fi
    
    debug_print continue "Wine version detected: $wine_version"
    return 0
}

############################################################################
# User Communication Functions
############################################################################

# Debug print function with different levels
debug_print() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "exit")
            echo "[ERROR] $message" >&2
            ;;
        "continue")
            if [[ $debug -eq 1 ]]; then
                echo "[DEBUG] $message" >&2
            fi
            ;;
        "info")
            echo "[INFO] $message"
            ;;
        *)
            echo "[LOG] $message"
            ;;
    esac
}

# Generic message function supporting both GUI and terminal
message() {
    local type="$1"
    local title="$2"
    local text="$3"
    
    case "$type" in
        "info")
            if [[ $gui_zenity -eq 1 ]]; then
                zenity --info --no-wrap --title="$script_name - $title" --text="$text" 2>/dev/null
            else
                echo
                echo "=== $title ==="
                echo -e "$text"
                echo
                read -p "Press Enter to continue..."
            fi
            ;;
        "error")
            if [[ $gui_zenity -eq 1 ]]; then
                zenity --error --no-wrap --title="$script_name - $title" --text="$text" 2>/dev/null
            else
                echo
                echo "=== ERROR: $title ==="
                echo -e "$text"
                echo
                read -p "Press Enter to continue..."
            fi
            ;;
        "question")
            if [[ $gui_zenity -eq 1 ]]; then
                zenity --question --no-wrap --title="$script_name - $title" --text="$text" 2>/dev/null
                return $?
            else
                echo
                echo "=== $title ==="
                echo -e "$text"
                echo
                while true; do
                    read -p "Continue? (y/n): " yn
                    case $yn in
                        [Yy]* ) return 0;;
                        [Nn]* ) return 1;;
                        * ) echo "Please answer yes or no.";;
                    esac
                done
            fi
            ;;
        *)
            debug_print exit "Unknown message type: $type"
            return 1
            ;;
    esac
}

# Generic menu function supporting both Zenity GUI and terminal modes
menu() {
    local menu_title="$1"
    local menu_text="$2"
    shift 2
    local menu_options=("$@")
    local selected_option=""
    
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        debug_print exit "No menu options provided"
        return 1
    fi
    
    if [[ $gui_zenity -eq 1 ]]; then
        # GUI mode using Zenity
        local zenity_options=()
        local i=1
        
        # Build zenity options array
        for option in "${menu_options[@]}"; do
            zenity_options+=("$i" "$option")
            ((i++))
        done
        
        # Display zenity menu
        selected_option=$(zenity --list \
            --title="$script_name - $menu_title" \
            --text="$menu_text" \
            --column="Option" \
            --column="Description" \
            --hide-column=1 \
            --print-column=1 \
            "${zenity_options[@]}" 2>/dev/null)
        
        # Handle zenity cancellation
        if [[ $? -ne 0 || -z "$selected_option" ]]; then
            return 1
        fi
        
    else
        # Terminal mode
        echo
        echo "=== $menu_title ==="
        if [[ -n "$menu_text" ]]; then
            echo -e "$menu_text"
            echo
        fi
        
        # Display menu options
        local i=1
        for option in "${menu_options[@]}"; do
            echo "$i) $option"
            ((i++))
        done
        echo "q) Quit"
        echo
        
        # Get user selection
        while true; do
            read -p "Please select an option: " selected_option
            
            # Handle quit
            if [[ "$selected_option" == "q" || "$selected_option" == "Q" ]]; then
                return 1
            fi
            
            # Validate numeric input
            if [[ "$selected_option" =~ ^[0-9]+$ ]] && \
               [[ "$selected_option" -ge 1 ]] && \
               [[ "$selected_option" -le ${#menu_options[@]} ]]; then
                break
            else
                echo "Invalid selection. Please enter a number between 1 and ${#menu_options[@]}, or 'q' to quit."
            fi
        done
    fi
    
    # Return the selected option number
    echo "$selected_option"
    return 0
}

# Menu loop control variable and function
menu_loop_done=0

# Function to control menu loop termination
menu_loop_done() {
    menu_loop_done=1
    debug_print continue "Menu loop termination requested"
}

# Function to reset menu loop control
menu_loop_reset() {
    menu_loop_done=0
    debug_print continue "Menu loop reset"
}

# Function to check if menu loop should continue
menu_should_continue() {
    if [[ $menu_loop_done -eq 1 ]]; then
        return 1  # Should exit
    else
        return 0  # Should continue
    fi
}

############################################################################
# Main Application Functions
############################################################################

# Display version information
show_version() {
    echo "$script_name v$script_version"
    echo "World of Warcraft Helper Script for Linux"
    echo
    echo "Based on lug-helper, adapted for Battle.net and WoW"
    echo "License: GPL-3.0"
}

# Display help information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo "  -d, --debug    Enable debug output"
    echo
    echo "$script_name is a helper script for managing World of Warcraft"
    echo "and Battle.net on Linux systems using wine/Proton Experimental."
    echo
    echo "Run without arguments to start the interactive menu."
}

# Initialize the application
initialize() {
    debug_print continue "Initializing $script_name..."
    
    # Setup configuration directories
    if ! setup_config_dirs; then
        debug_print exit "Failed to setup configuration directories"
        return 1
    fi
    
    # Load existing configuration
    getdirs
    
    # Check dependencies
    if ! check_dependencies; then
        debug_print exit "Dependency check failed"
        return 1
    fi
    
    debug_print continue "$script_name initialized successfully"
    return 0
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                debug=1
                debug_print continue "Debug mode enabled"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Initialize application
    if ! initialize; then
        debug_print exit "Application initialization failed"
        exit 1
    fi
    
    # Welcome message
    message info "Welcome" "Welcome to $script_name!\n\nThis helper script will assist you with installing and optimizing World of Warcraft and Battle.net on Linux.\n\nCore utility functions and menu system are now implemented.\nAdditional features will be added in subsequent tasks."
    
    debug_print continue "$script_name startup completed"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi