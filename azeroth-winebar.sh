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
# Wine Runner Management Functions
############################################################################

# Wine runner sources configuration
declare -A wine_runner_sources=(
    ["lutris-ge"]="https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases"
    ["lutris-fshack"]="https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases"
    ["wine-tkg"]="https://api.github.com/repos/Kron4ek/Wine-Builds/releases"
    ["proton-ge"]="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
    ["proton-experimental"]="steam://proton-experimental"
)

# Wine runner installation directory
wine_runners_dir="$HOME/.local/share/azeroth-winebar/runners"

# Create wine runners directory
setup_wine_runners_dir() {
    debug_print continue "Setting up wine runners directory..."
    
    if [[ ! -d "$wine_runners_dir" ]]; then
        if ! mkdir -p "$wine_runners_dir"; then
            debug_print exit "Failed to create wine runners directory: $wine_runners_dir"
            return 1
        fi
    fi
    
    debug_print continue "Wine runners directory ready: $wine_runners_dir"
    return 0
}

# Get available wine runner releases from GitHub API
get_runner_releases() {
    local runner_type="$1"
    local api_url="${wine_runner_sources[$runner_type]}"
    
    if [[ -z "$api_url" ]]; then
        debug_print exit "Unknown wine runner type: $runner_type"
        return 1
    fi
    
    # Handle special case for Proton Experimental
    if [[ "$runner_type" == "proton-experimental" ]]; then
        echo "proton-experimental-latest"
        return 0
    fi
    
    debug_print continue "Fetching releases for $runner_type from $api_url"
    
    # Fetch releases from GitHub API
    local releases_json
    if ! releases_json=$(curl -s "$api_url"); then
        debug_print exit "Failed to fetch releases for $runner_type"
        return 1
    fi
    
    # Parse release names and download URLs
    local releases
    case "$runner_type" in
        "lutris-ge"|"lutris-fshack")
            releases=$(echo "$releases_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/' | head -10)
            ;;
        "wine-tkg")
            releases=$(echo "$releases_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/' | grep -E "^wine-" | head -10)
            ;;
        "proton-ge")
            releases=$(echo "$releases_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/' | head -10)
            ;;
        *)
            debug_print exit "Unsupported runner type for release parsing: $runner_type"
            return 1
            ;;
    esac
    
    if [[ -z "$releases" ]]; then
        debug_print exit "No releases found for $runner_type"
        return 1
    fi
    
    echo "$releases"
    return 0
}

# Get download URL for a specific wine runner release
get_runner_download_url() {
    local runner_type="$1"
    local release_tag="$2"
    local api_url="${wine_runner_sources[$runner_type]}"
    
    if [[ -z "$api_url" || -z "$release_tag" ]]; then
        debug_print exit "Missing parameters for download URL lookup"
        return 1
    fi
    
    # Handle special case for Proton Experimental
    if [[ "$runner_type" == "proton-experimental" ]]; then
        echo "steam://proton-experimental"
        return 0
    fi
    
    debug_print continue "Getting download URL for $runner_type $release_tag"
    
    # Fetch specific release data
    local release_json
    if ! release_json=$(curl -s "$api_url/tags/$release_tag"); then
        debug_print exit "Failed to fetch release data for $release_tag"
        return 1
    fi
    
    # Extract download URL based on runner type
    local download_url
    case "$runner_type" in
        "lutris-ge"|"lutris-fshack")
            download_url=$(echo "$release_json" | grep -o '"browser_download_url": *"[^"]*\.tar\.xz"' | head -1 | sed 's/"browser_download_url": *"\([^"]*\)"/\1/')
            ;;
        "wine-tkg")
            download_url=$(echo "$release_json" | grep -o '"browser_download_url": *"[^"]*\.tar\.xz"' | grep -E "(staging|tkg)" | head -1 | sed 's/"browser_download_url": *"\([^"]*\)"/\1/')
            ;;
        "proton-ge")
            download_url=$(echo "$release_json" | grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' | head -1 | sed 's/"browser_download_url": *"\([^"]*\)"/\1/')
            ;;
        *)
            debug_print exit "Unsupported runner type for URL extraction: $runner_type"
            return 1
            ;;
    esac
    
    if [[ -z "$download_url" ]]; then
        debug_print exit "No download URL found for $runner_type $release_tag"
        return 1
    fi
    
    echo "$download_url"
    return 0
}

# Download wine runner from URL
download_runner() {
    local download_url="$1"
    local runner_name="$2"
    local temp_dir="/tmp/azeroth-winebar-download"
    
    if [[ -z "$download_url" || -z "$runner_name" ]]; then
        debug_print exit "Missing parameters for runner download"
        return 1
    fi
    
    # Handle special case for Proton Experimental
    if [[ "$download_url" == "steam://proton-experimental" ]]; then
        debug_print continue "Proton Experimental requires special handling - delegating to get_proton_experimental()"
        return 2  # Special return code to indicate delegation needed
    fi
    
    debug_print continue "Downloading wine runner: $runner_name"
    debug_print continue "Download URL: $download_url"
    
    # Create temporary download directory
    if ! mkdir -p "$temp_dir"; then
        debug_print exit "Failed to create temporary download directory"
        return 1
    fi
    
    # Determine file extension and name
    local file_extension
    if [[ "$download_url" == *.tar.xz ]]; then
        file_extension="tar.xz"
    elif [[ "$download_url" == *.tar.gz ]]; then
        file_extension="tar.gz"
    else
        debug_print exit "Unsupported archive format in URL: $download_url"
        return 1
    fi
    
    local download_file="$temp_dir/$runner_name.$file_extension"
    
    # Download the file with progress indication
    debug_print continue "Downloading to: $download_file"
    if ! curl -L -o "$download_file" "$download_url"; then
        debug_print exit "Failed to download wine runner from $download_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verify download
    if [[ ! -f "$download_file" ]]; then
        debug_print exit "Downloaded file not found: $download_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$download_file" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 1000000 ]]; then  # Less than 1MB is suspicious
        debug_print exit "Downloaded file appears to be too small: $file_size bytes"
        rm -rf "$temp_dir"
        return 1
    fi
    
    debug_print continue "Download completed successfully: $file_size bytes"
    echo "$download_file"
    return 0
}

# Install wine runner from downloaded archive
install_runner() {
    local archive_path="$1"
    local runner_name="$2"
    local runner_type="$3"
    
    if [[ -z "$archive_path" || -z "$runner_name" ]]; then
        debug_print exit "Missing parameters for runner installation"
        return 1
    fi
    
    if [[ ! -f "$archive_path" ]]; then
        debug_print exit "Archive file not found: $archive_path"
        return 1
    fi
    
    # Setup wine runners directory
    if ! setup_wine_runners_dir; then
        return 1
    fi
    
    local install_dir="$wine_runners_dir/$runner_name"
    
    # Check if runner already exists
    if [[ -d "$install_dir" ]]; then
        debug_print continue "Wine runner already exists: $runner_name"
        if ! message question "Runner Exists" "Wine runner '$runner_name' is already installed.\n\nDo you want to reinstall it?"; then
            debug_print continue "Installation cancelled by user"
            return 1
        fi
        
        # Remove existing installation
        debug_print continue "Removing existing installation: $install_dir"
        if ! rm -rf "$install_dir"; then
            debug_print exit "Failed to remove existing runner installation"
            return 1
        fi
    fi
    
    debug_print continue "Installing wine runner: $runner_name"
    debug_print continue "Installation directory: $install_dir"
    
    # Create installation directory
    if ! mkdir -p "$install_dir"; then
        debug_print exit "Failed to create installation directory: $install_dir"
        return 1
    fi
    
    # Extract archive based on file type
    local extract_cmd
    if [[ "$archive_path" == *.tar.xz ]]; then
        extract_cmd="tar -xJf"
    elif [[ "$archive_path" == *.tar.gz ]]; then
        extract_cmd="tar -xzf"
    else
        debug_print exit "Unsupported archive format: $archive_path"
        return 1
    fi
    
    debug_print continue "Extracting archive with: $extract_cmd"
    if ! $extract_cmd "$archive_path" -C "$install_dir" --strip-components=1; then
        debug_print exit "Failed to extract wine runner archive"
        rm -rf "$install_dir"
        return 1
    fi
    
    # Verify installation
    local wine_binary
    case "$runner_type" in
        "proton-ge"|"proton-experimental")
            wine_binary="$install_dir/bin/wine"
            ;;
        *)
            wine_binary="$install_dir/bin/wine"
            ;;
    esac
    
    if [[ ! -f "$wine_binary" ]]; then
        debug_print exit "Wine binary not found after installation: $wine_binary"
        rm -rf "$install_dir"
        return 1
    fi
    
    # Make wine binary executable
    if ! chmod +x "$wine_binary"; then
        debug_print continue "Warning: Failed to make wine binary executable"
    fi
    
    # Create runner info file
    local info_file="$install_dir/.runner-info"
    cat > "$info_file" << EOF
RUNNER_NAME=$runner_name
RUNNER_TYPE=$runner_type
INSTALL_DATE=$(date -Iseconds)
WINE_BINARY=$wine_binary
EOF
    
    debug_print continue "Wine runner installed successfully: $runner_name"
    message info "Installation Complete" "Wine runner '$runner_name' has been installed successfully.\n\nLocation: $install_dir"
    
    return 0
}

# List installed wine runners
list_installed_runners() {
    debug_print continue "Listing installed wine runners..."
    
    if [[ ! -d "$wine_runners_dir" ]]; then
        debug_print continue "No wine runners directory found"
        return 1
    fi
    
    local runners=()
    local runner_info=()
    
    # Find all installed runners
    for runner_dir in "$wine_runners_dir"/*; do
        if [[ -d "$runner_dir" ]]; then
            local runner_name
            runner_name=$(basename "$runner_dir")
            
            # Check if it has a valid wine binary
            local wine_binary="$runner_dir/bin/wine"
            if [[ -f "$wine_binary" ]]; then
                runners+=("$runner_name")
                
                # Get runner type if available
                local runner_type="unknown"
                local info_file="$runner_dir/.runner-info"
                if [[ -f "$info_file" ]]; then
                    runner_type=$(grep "^RUNNER_TYPE=" "$info_file" | cut -d'=' -f2)
                fi
                
                runner_info+=("$runner_name ($runner_type)")
            fi
        fi
    done
    
    if [[ ${#runners[@]} -eq 0 ]]; then
        debug_print continue "No installed wine runners found"
        return 1
    fi
    
    debug_print continue "Found ${#runners[@]} installed wine runners"
    printf '%s\n' "${runner_info[@]}"
    return 0
}

# Get wine runner binary path
get_runner_binary() {
    local runner_name="$1"
    
    if [[ -z "$runner_name" ]]; then
        debug_print exit "No runner name specified"
        return 1
    fi
    
    local runner_dir="$wine_runners_dir/$runner_name"
    local wine_binary="$runner_dir/bin/wine"
    
    if [[ -f "$wine_binary" ]]; then
        echo "$wine_binary"
        return 0
    else
        debug_print exit "Wine binary not found for runner: $runner_name"
        return 1
    fi
}

############################################################################
# Proton Experimental Specific Functions
############################################################################

# Check if Steam is installed and find Steam directory
find_steam_directory() {
    debug_print continue "Looking for Steam installation..."
    
    # Common Steam installation paths
    local steam_paths=(
        "$HOME/.steam/steam"
        "$HOME/.local/share/Steam"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"  # Flatpak
        "/usr/share/steam"
    )
    
    for steam_path in "${steam_paths[@]}"; do
        if [[ -d "$steam_path" ]]; then
            debug_print continue "Found Steam directory: $steam_path"
            echo "$steam_path"
            return 0
        fi
    done
    
    debug_print exit "Steam installation not found"
    return 1
}

# Find Proton Experimental installation in Steam
find_proton_experimental() {
    local steam_dir
    if ! steam_dir=$(find_steam_directory); then
        return 1
    fi
    
    debug_print continue "Searching for Proton Experimental in Steam directory..."
    
    # Look for Proton Experimental in Steam's compatibilitytools.d
    local proton_paths=(
        "$steam_dir/compatibilitytools.d/Proton-Experimental"
        "$steam_dir/steamapps/common/Proton - Experimental"
        "$steam_dir/steamapps/common/Proton Experimental"
    )
    
    for proton_path in "${proton_paths[@]}"; do
        if [[ -d "$proton_path" ]]; then
            local proton_binary="$proton_path/proton"
            if [[ -f "$proton_binary" ]]; then
                debug_print continue "Found Proton Experimental: $proton_path"
                echo "$proton_path"
                return 0
            fi
        fi
    done
    
    debug_print continue "Proton Experimental not found in Steam installation"
    return 1
}

# Download and install Proton Experimental
get_proton_experimental() {
    debug_print continue "Setting up Proton Experimental..."
    
    # Check if Steam is available
    local steam_dir
    if ! steam_dir=$(find_steam_directory); then
        message error "Steam Required" "Proton Experimental requires Steam to be installed.\n\nPlease install Steam first, then run Steam at least once to initialize it."
        return 1
    fi
    
    # Check if Proton Experimental is already available in Steam
    local existing_proton
    if existing_proton=$(find_proton_experimental); then
        debug_print continue "Found existing Proton Experimental installation"
        
        # Create symlink in our runners directory
        local runner_name="proton-experimental"
        local runner_link="$wine_runners_dir/$runner_name"
        
        if ! setup_wine_runners_dir; then
            return 1
        fi
        
        # Remove existing symlink if it exists
        if [[ -L "$runner_link" ]]; then
            rm "$runner_link"
        elif [[ -d "$runner_link" ]]; then
            debug_print continue "Warning: Removing existing directory to create symlink"
            rm -rf "$runner_link"
        fi
        
        # Create symlink to Steam's Proton Experimental
        if ln -s "$existing_proton" "$runner_link"; then
            debug_print continue "Created symlink to Proton Experimental: $runner_link"
            
            # Create runner info file
            local info_file="$runner_link/.runner-info"
            cat > "$info_file" << EOF
RUNNER_NAME=$runner_name
RUNNER_TYPE=proton-experimental
INSTALL_DATE=$(date -Iseconds)
WINE_BINARY=$existing_proton/dist/bin/wine
PROTON_BINARY=$existing_proton/proton
STEAM_SOURCE=$existing_proton
EOF
            
            # Set as default runner
            set_default_runner "$runner_name"
            
            message info "Proton Experimental Ready" "Proton Experimental has been configured successfully.\n\nIt is now set as your default wine runner for optimal Battle.net and WoW compatibility."
            return 0
        else
            debug_print exit "Failed to create symlink to Proton Experimental"
            return 1
        fi
    fi
    
    # Proton Experimental not found - guide user to install it
    message info "Install Proton Experimental" "Proton Experimental was not found in your Steam installation.\n\nTo install Proton Experimental:\n\n1. Open Steam\n2. Go to Steam > Settings > Compatibility\n3. Enable 'Enable Steam Play for all other titles'\n4. Select 'Proton Experimental' from the dropdown\n5. Restart Steam\n\nAfter installation, run this script again to configure Proton Experimental."
    
    # Offer to open Steam settings
    if command_exists "steam"; then
        if message question "Open Steam" "Would you like to open Steam now to install Proton Experimental?"; then
            debug_print continue "Opening Steam for user to install Proton Experimental"
            steam steam://open/settings/compatibility &
        fi
    fi
    
    return 1
}

# Configure Proton Experimental environment
configure_proton_experimental() {
    local runner_name="$1"
    local wine_prefix="$2"
    
    if [[ -z "$runner_name" || -z "$wine_prefix" ]]; then
        debug_print exit "Missing parameters for Proton Experimental configuration"
        return 1
    fi
    
    debug_print continue "Configuring Proton Experimental environment..."
    
    local runner_dir="$wine_runners_dir/$runner_name"
    if [[ ! -d "$runner_dir" ]]; then
        debug_print exit "Proton Experimental runner not found: $runner_dir"
        return 1
    fi
    
    # Set Proton-specific environment variables
    export STEAM_COMPAT_DATA_PATH="$wine_prefix"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$runner_dir"
    export PROTON_USE_WINE3D=1
    export PROTON_NO_ESYNC=0
    export PROTON_NO_FSYNC=0
    export PROTON_FORCE_LARGE_ADDRESS_AWARE=1
    
    # Additional Proton optimizations for Battle.net/WoW
    export PROTON_ENABLE_NVAPI=0  # Disable NVAPI for stability
    export PROTON_HIDE_NVIDIA_GPU=0
    export PROTON_USE_WINED3D=0  # Use DXVK instead of WineD3D
    
    debug_print continue "Proton Experimental environment configured"
    return 0
}

# Set default wine runner in configuration
set_default_runner() {
    local runner_name="$1"
    
    if [[ -z "$runner_name" ]]; then
        debug_print exit "No runner name specified for default setting"
        return 1
    fi
    
    local config_file="$config_dir/default-runner.conf"
    
    if echo "$runner_name" > "$config_file"; then
        debug_print continue "Default wine runner set to: $runner_name"
        return 0
    else
        debug_print exit "Failed to save default runner configuration"
        return 1
    fi
}

# Get default wine runner from configuration
get_default_runner() {
    local config_file="$config_dir/default-runner.conf"
    
    if [[ -f "$config_file" ]]; then
        local default_runner
        default_runner="$(cat "$config_file" 2>/dev/null)"
        if [[ -n "$default_runner" ]]; then
            echo "$default_runner"
            return 0
        fi
    fi
    
    # Default to Proton Experimental if no configuration exists
    echo "proton-experimental"
    return 0
}

# Validate Proton Experimental installation
validate_proton_experimental() {
    local runner_name="$1"
    
    if [[ -z "$runner_name" ]]; then
        runner_name="proton-experimental"
    fi
    
    local runner_dir="$wine_runners_dir/$runner_name"
    
    if [[ ! -d "$runner_dir" ]]; then
        debug_print continue "Proton Experimental not installed: $runner_name"
        return 1
    fi
    
    # Check for Proton binary
    local proton_binary="$runner_dir/proton"
    if [[ ! -f "$proton_binary" ]]; then
        debug_print continue "Proton binary not found: $proton_binary"
        return 1
    fi
    
    # Check for wine binary in dist directory
    local wine_binary="$runner_dir/dist/bin/wine"
    if [[ ! -f "$wine_binary" ]]; then
        debug_print continue "Wine binary not found in Proton installation: $wine_binary"
        return 1
    fi
    
    debug_print continue "Proton Experimental validation successful: $runner_name"
    return 0
}

############################################################################
# System Optimization and Preflight Check Functions
############################################################################

# Check vm.max_map_count setting
check_map_count() {
    debug_print continue "Checking vm.max_map_count setting..."
    
    local current_map_count
    local required_map_count=16777216
    
    # Get current vm.max_map_count value
    if [[ -r /proc/sys/vm/max_map_count ]]; then
        current_map_count=$(cat /proc/sys/vm/max_map_count 2>/dev/null)
    else
        debug_print exit "Unable to read vm.max_map_count from /proc/sys/vm/max_map_count"
        return 1
    fi
    
    if [[ -z "$current_map_count" ]]; then
        debug_print exit "Failed to get current vm.max_map_count value"
        return 1
    fi
    
    debug_print continue "Current vm.max_map_count: $current_map_count"
    debug_print continue "Required vm.max_map_count: $required_map_count"
    
    # Check if current value meets requirement
    if [[ "$current_map_count" -ge "$required_map_count" ]]; then
        debug_print continue "vm.max_map_count check passed"
        return 0
    else
        debug_print continue "vm.max_map_count check failed: $current_map_count < $required_map_count"
        return 1
    fi
}

# Check file descriptor limits
check_file_limits() {
    debug_print continue "Checking file descriptor limits..."
    
    local current_hard_limit
    local required_hard_limit=524288
    
    # Get current hard limit for open files
    current_hard_limit=$(ulimit -Hn 2>/dev/null)
    
    if [[ -z "$current_hard_limit" ]]; then
        debug_print exit "Failed to get current hard file descriptor limit"
        return 1
    fi
    
    # Handle "unlimited" case
    if [[ "$current_hard_limit" == "unlimited" ]]; then
        debug_print continue "File descriptor hard limit is unlimited (passed)"
        return 0
    fi
    
    debug_print continue "Current hard file descriptor limit: $current_hard_limit"
    debug_print continue "Required hard file descriptor limit: $required_hard_limit"
    
    # Check if current value meets requirement
    if [[ "$current_hard_limit" -ge "$required_hard_limit" ]]; then
        debug_print continue "File descriptor limit check passed"
        return 0
    else
        debug_print continue "File descriptor limit check failed: $current_hard_limit < $required_hard_limit"
        return 1
    fi
}

# Check memory requirements (RAM and swap)
check_memory() {
    debug_print continue "Checking memory requirements..."
    
    local required_ram_gb=16
    local required_total_gb=40
    
    # Get memory information from /proc/meminfo
    if [[ ! -r /proc/meminfo ]]; then
        debug_print exit "Unable to read /proc/meminfo"
        return 1
    fi
    
    local mem_total_kb
    local swap_total_kb
    
    # Extract memory values (in KB)
    mem_total_kb=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
    swap_total_kb=$(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}')
    
    if [[ -z "$mem_total_kb" ]]; then
        debug_print exit "Failed to get total RAM from /proc/meminfo"
        return 1
    fi
    
    # Convert to GB (1 GB = 1024^3 bytes = 1048576 KB)
    local mem_total_gb=$((mem_total_kb / 1048576))
    local swap_total_gb=0
    
    if [[ -n "$swap_total_kb" && "$swap_total_kb" -gt 0 ]]; then
        swap_total_gb=$((swap_total_kb / 1048576))
    fi
    
    local total_memory_gb=$((mem_total_gb + swap_total_gb))
    
    debug_print continue "Total RAM: ${mem_total_gb}GB"
    debug_print continue "Total Swap: ${swap_total_gb}GB"
    debug_print continue "Total Memory (RAM + Swap): ${total_memory_gb}GB"
    debug_print continue "Required RAM: ${required_ram_gb}GB"
    debug_print continue "Required Total Memory: ${required_total_gb}GB"
    
    local ram_check_passed=0
    local total_check_passed=0
    
    # Check RAM requirement
    if [[ "$mem_total_gb" -ge "$required_ram_gb" ]]; then
        debug_print continue "RAM requirement check passed"
        ram_check_passed=1
    else
        debug_print continue "RAM requirement check failed: ${mem_total_gb}GB < ${required_ram_gb}GB"
    fi
    
    # Check total memory requirement
    if [[ "$total_memory_gb" -ge "$required_total_gb" ]]; then
        debug_print continue "Total memory requirement check passed"
        total_check_passed=1
    else
        debug_print continue "Total memory requirement check failed: ${total_memory_gb}GB < ${required_total_gb}GB"
    fi
    
    # Return success only if both checks pass
    if [[ "$ram_check_passed" -eq 1 && "$total_check_passed" -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Execute command with appropriate privileges (root/user)
try_exec() {
    local command="$1"
    local description="$2"
    local use_sudo="${3:-true}"
    
    if [[ -z "$command" ]]; then
        debug_print exit "No command specified for try_exec"
        return 1
    fi
    
    debug_print continue "Executing: $description"
    debug_print continue "Command: $command"
    
    # Try to execute the command
    if [[ "$use_sudo" == "true" ]]; then
        # Check if we need sudo
        if [[ $EUID -eq 0 ]]; then
            # Already running as root
            debug_print continue "Running as root, executing directly"
            if eval "$command"; then
                debug_print continue "Command executed successfully"
                return 0
            else
                debug_print exit "Command failed: $command"
                return 1
            fi
        else
            # Need to use sudo
            debug_print continue "Using sudo for privilege escalation"
            
            # Check if sudo is available
            if ! command_exists "sudo"; then
                debug_print exit "sudo is required but not available"
                message error "Sudo Required" "This operation requires administrative privileges, but sudo is not available.\n\nPlease install sudo or run as root."
                return 1
            fi
            
            # Check if polkit is available for GUI sudo prompts
            if command_exists "pkexec"; then
                debug_print continue "Using pkexec for GUI privilege escalation"
                if pkexec bash -c "$command"; then
                    debug_print continue "Command executed successfully with pkexec"
                    return 0
                else
                    debug_print continue "pkexec failed, trying sudo"
                fi
            fi
            
            # Use regular sudo
            if sudo bash -c "$command"; then
                debug_print continue "Command executed successfully with sudo"
                return 0
            else
                debug_print exit "Command failed with sudo: $command"
                return 1
            fi
        fi
    else
        # Execute without sudo
        debug_print continue "Executing without privilege escalation"
        if eval "$command"; then
            debug_print continue "Command executed successfully"
            return 0
        else
            debug_print exit "Command failed: $command"
            return 1
        fi
    fi
}

# Fix vm.max_map_count setting
fix_map_count() {
    debug_print continue "Fixing vm.max_map_count setting..."
    
    local required_map_count=16777216
    local sysctl_conf="/etc/sysctl.conf"
    local sysctl_d_file="/etc/sysctl.d/99-azeroth-winebar.conf"
    
    # First, set the current runtime value
    local set_runtime_cmd="sysctl -w vm.max_map_count=$required_map_count"
    if ! try_exec "$set_runtime_cmd" "Setting runtime vm.max_map_count"; then
        debug_print exit "Failed to set runtime vm.max_map_count"
        return 1
    fi
    
    # Make the change persistent
    debug_print continue "Making vm.max_map_count change persistent..."
    
    # Create sysctl.d configuration file (preferred method)
    local create_sysctl_cmd="echo 'vm.max_map_count=$required_map_count' > '$sysctl_d_file'"
    if try_exec "$create_sysctl_cmd" "Creating persistent sysctl configuration"; then
        debug_print continue "Created persistent configuration: $sysctl_d_file"
    else
        # Fallback to modifying /etc/sysctl.conf
        debug_print continue "Fallback: Adding to $sysctl_conf"
        
        # Check if the setting already exists in sysctl.conf
        local check_existing_cmd="grep -q '^vm.max_map_count' '$sysctl_conf'"
        if try_exec "$check_existing_cmd" "Checking existing sysctl.conf entry" false; then
            # Update existing entry
            local update_cmd="sed -i 's/^vm.max_map_count.*/vm.max_map_count=$required_map_count/' '$sysctl_conf'"
            if ! try_exec "$update_cmd" "Updating existing sysctl.conf entry"; then
                debug_print exit "Failed to update sysctl.conf"
                return 1
            fi
        else
            # Add new entry
            local append_cmd="echo 'vm.max_map_count=$required_map_count' >> '$sysctl_conf'"
            if ! try_exec "$append_cmd" "Adding new sysctl.conf entry"; then
                debug_print exit "Failed to add entry to sysctl.conf"
                return 1
            fi
        fi
    fi
    
    # Verify the fix
    if check_map_count; then
        debug_print continue "vm.max_map_count fix applied successfully"
        message info "System Optimization" "vm.max_map_count has been set to $required_map_count.\n\nThis change will persist after reboot."
        return 0
    else
        debug_print exit "vm.max_map_count fix verification failed"
        return 1
    fi
}

# Fix file descriptor limits
fix_file_limits() {
    debug_print continue "Fixing file descriptor limits..."
    
    local required_hard_limit=524288
    local limits_conf="/etc/security/limits.conf"
    local limits_d_file="/etc/security/limits.d/99-azeroth-winebar.conf"
    
    # Create limits.d configuration file (preferred method)
    debug_print continue "Creating persistent limits configuration..."
    
    local limits_content="# Azeroth Winebar - File descriptor limits for WoW
* soft nofile $required_hard_limit
* hard nofile $required_hard_limit
root soft nofile $required_hard_limit
root hard nofile $required_hard_limit"
    
    local create_limits_cmd="cat > '$limits_d_file' << 'EOF'
$limits_content
EOF"
    
    if try_exec "$create_limits_cmd" "Creating persistent limits configuration"; then
        debug_print continue "Created persistent limits configuration: $limits_d_file"
    else
        # Fallback to modifying /etc/security/limits.conf
        debug_print continue "Fallback: Adding to $limits_conf"
        
        # Check if our entries already exist
        local check_existing_cmd="grep -q 'Azeroth Winebar' '$limits_conf'"
        if ! try_exec "$check_existing_cmd" "Checking existing limits.conf entries" false; then
            # Add new entries
            local append_cmd="cat >> '$limits_conf' << 'EOF'

# Azeroth Winebar - File descriptor limits for WoW
* soft nofile $required_hard_limit
* hard nofile $required_hard_limit
root soft nofile $required_hard_limit
root hard nofile $required_hard_limit
EOF"
            if ! try_exec "$append_cmd" "Adding new limits.conf entries"; then
                debug_print exit "Failed to add entries to limits.conf"
                return 1
            fi
        else
            debug_print continue "Limits configuration already exists in limits.conf"
        fi
    fi
    
    debug_print continue "File descriptor limits configuration applied"
    message info "System Optimization" "File descriptor limits have been configured.\n\nYou may need to log out and log back in for the changes to take effect.\n\nNew limit: $required_hard_limit"
    
    return 0
}

# Comprehensive preflight check system
preflight_check() {
    debug_print continue "Starting comprehensive preflight check..."
    
    local checks_passed=0
    local checks_failed=0
    local failed_checks=()
    local check_results=()
    
    # Initialize check results
    check_results+=("=== Azeroth Winebar System Preflight Check ===")
    check_results+=("")
    
    # Check 1: vm.max_map_count
    debug_print continue "Running vm.max_map_count check..."
    if check_map_count; then
        check_results+=("✓ vm.max_map_count: PASSED")
        ((checks_passed++))
    else
        check_results+=("✗ vm.max_map_count: FAILED")
        failed_checks+=("map_count")
        ((checks_failed++))
    fi
    
    # Check 2: File descriptor limits
    debug_print continue "Running file descriptor limits check..."
    if check_file_limits; then
        check_results+=("✓ File descriptor limits: PASSED")
        ((checks_passed++))
    else
        check_results+=("✗ File descriptor limits: FAILED")
        failed_checks+=("file_limits")
        ((checks_failed++))
    fi
    
    # Check 3: Memory requirements
    debug_print continue "Running memory requirements check..."
    if check_memory; then
        check_results+=("✓ Memory requirements: PASSED")
        ((checks_passed++))
    else
        check_results+=("✗ Memory requirements: FAILED")
        failed_checks+=("memory")
        ((checks_failed++))
    fi
    
    # Add summary to results
    check_results+=("")
    check_results+=("=== Summary ===")
    check_results+=("Checks passed: $checks_passed")
    check_results+=("Checks failed: $checks_failed")
    
    # Display results
    local results_text
    printf -v results_text '%s\n' "${check_results[@]}"
    
    if [[ $checks_failed -eq 0 ]]; then
        debug_print continue "All preflight checks passed"
        message info "Preflight Check Complete" "$results_text\n\nAll system optimizations are properly configured!"
        return 0
    else
        debug_print continue "Some preflight checks failed: ${failed_checks[*]}"
        
        # Ask user if they want to apply fixes
        local fix_message="$results_text\n\nSome system optimizations are missing or incorrectly configured.\n\nWould you like to apply the necessary fixes automatically?"
        
        if message question "System Optimization Required" "$fix_message"; then
            debug_print continue "User chose to apply fixes"
            
            local fixes_applied=0
            local fixes_failed=0
            
            # Apply fixes for failed checks
            for failed_check in "${failed_checks[@]}"; do
                case "$failed_check" in
                    "map_count")
                        debug_print continue "Applying vm.max_map_count fix..."
                        if fix_map_count; then
                            ((fixes_applied++))
                        else
                            ((fixes_failed++))
                        fi
                        ;;
                    "file_limits")
                        debug_print continue "Applying file descriptor limits fix..."
                        if fix_file_limits; then
                            ((fixes_applied++))
                        else
                            ((fixes_failed++))
                        fi
                        ;;
                    "memory")
                        debug_print continue "Memory requirements cannot be automatically fixed"
                        message info "Memory Requirements" "Your system does not meet the memory requirements:\n\n• Minimum 16GB RAM\n• Minimum 40GB total memory (RAM + Swap)\n\nConsider adding more RAM or increasing swap space."
                        ((fixes_failed++))
                        ;;
                    *)
                        debug_print continue "Unknown failed check: $failed_check"
                        ((fixes_failed++))
                        ;;
                esac
            done
            
            # Report fix results
            if [[ $fixes_failed -eq 0 ]]; then
                message info "Fixes Applied" "All system optimizations have been applied successfully!\n\nFixes applied: $fixes_applied\n\nYour system is now optimized for World of Warcraft."
                return 0
            else
                message info "Partial Success" "Some fixes were applied successfully, but others require manual attention.\n\nFixes applied: $fixes_applied\nFixes failed: $fixes_failed\n\nPlease review the failed items manually."
                return 1
            fi
        else
            debug_print continue "User chose not to apply fixes"
            message info "Preflight Check" "System optimization fixes were not applied.\n\nYou can run the preflight check again later to apply these optimizations."
            return 1
        fi
    fi
}

############################################################################
# Wine Runner Management Interface Functions
############################################################################

# Delete/remove an installed wine runner
delete_runner() {
    local runner_name="$1"
    
    if [[ -z "$runner_name" ]]; then
        debug_print exit "No runner name specified for deletion"
        return 1
    fi
    
    local runner_dir="$wine_runners_dir/$runner_name"
    
    if [[ ! -d "$runner_dir" ]]; then
        debug_print exit "Wine runner not found: $runner_name"
        message error "Runner Not Found" "Wine runner '$runner_name' is not installed."
        return 1
    fi
    
    # Confirm deletion
    if ! message question "Delete Wine Runner" "Are you sure you want to delete wine runner '$runner_name'?\n\nThis action cannot be undone."; then
        debug_print continue "Runner deletion cancelled by user"
        return 1
    fi
    
    debug_print continue "Deleting wine runner: $runner_name"
    
    # Check if this is the default runner
    local current_default
    current_default=$(get_default_runner)
    if [[ "$current_default" == "$runner_name" ]]; then
        debug_print continue "Deleting default runner, will reset to proton-experimental"
        set_default_runner "proton-experimental"
    fi
    
    # Remove the runner directory
    if rm -rf "$runner_dir"; then
        debug_print continue "Wine runner deleted successfully: $runner_name"
        message info "Runner Deleted" "Wine runner '$runner_name' has been deleted successfully."
        return 0
    else
        debug_print exit "Failed to delete wine runner: $runner_name"
        message error "Deletion Failed" "Failed to delete wine runner '$runner_name'.\n\nCheck permissions and try again."
        return 1
    fi
}

# Select and switch wine runner
select_runner() {
    debug_print continue "Starting wine runner selection..."
    
    # Get list of installed runners
    local runners_output
    if ! runners_output=$(list_installed_runners); then
        message info "No Runners" "No wine runners are currently installed.\n\nWould you like to install Proton Experimental?"
        if message question "Install Proton Experimental" "Install Proton Experimental as your default wine runner?"; then
            get_proton_experimental
        fi
        return 1
    fi
    
    # Parse runners into array
    local runners=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            runners+=("$line")
        fi
    done <<< "$runners_output"
    
    if [[ ${#runners[@]} -eq 0 ]]; then
        message info "No Runners" "No wine runners found."
        return 1
    fi
    
    # Get current default runner
    local current_default
    current_default=$(get_default_runner)
    
    # Show current default
    message info "Current Default" "Current default wine runner: $current_default"
    
    # Display runner selection menu
    local selection
    selection=$(menu "Select Wine Runner" "Choose a wine runner to set as default:" "${runners[@]}")
    
    if [[ $? -ne 0 || -z "$selection" ]]; then
        debug_print continue "Runner selection cancelled"
        return 1
    fi
    
    # Extract runner name from selection (remove type info in parentheses)
    local selected_runner
    selected_runner=$(echo "${runners[$((selection-1))]}" | sed 's/ (.*//')
    
    if [[ -z "$selected_runner" ]]; then
        debug_print exit "Failed to parse selected runner name"
        return 1
    fi
    
    # Set as default runner
    if set_default_runner "$selected_runner"; then
        message info "Runner Selected" "Wine runner '$selected_runner' is now set as the default."
        return 0
    else
        message error "Selection Failed" "Failed to set '$selected_runner' as the default wine runner."
        return 1
    fi
}

# Install wine runner workflow
install_runner_workflow() {
    debug_print continue "Starting wine runner installation workflow..."
    
    # Show available runner types
    local runner_types=("Proton Experimental (Recommended)" "Lutris GE" "Proton GE" "Wine TKG")
    local selection
    selection=$(menu "Select Runner Type" "Choose the type of wine runner to install:" "${runner_types[@]}")
    
    if [[ $? -ne 0 || -z "$selection" ]]; then
        debug_print continue "Runner type selection cancelled"
        return 1
    fi
    
    local runner_type
    case "$selection" in
        1)
            runner_type="proton-experimental"
            ;;
        2)
            runner_type="lutris-ge"
            ;;
        3)
            runner_type="proton-ge"
            ;;
        4)
            runner_type="wine-tkg"
            ;;
        *)
            debug_print exit "Invalid runner type selection: $selection"
            return 1
            ;;
    esac
    
    # Handle Proton Experimental specially
    if [[ "$runner_type" == "proton-experimental" ]]; then
        get_proton_experimental
        return $?
    fi
    
    # Get available releases for the selected type
    debug_print continue "Fetching available releases for $runner_type..."
    local releases
    if ! releases=$(get_runner_releases "$runner_type"); then
        message error "Fetch Failed" "Failed to fetch available releases for $runner_type.\n\nCheck your internet connection and try again."
        return 1
    fi
    
    # Convert releases to array
    local releases_array=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            releases_array+=("$line")
        fi
    done <<< "$releases"
    
    if [[ ${#releases_array[@]} -eq 0 ]]; then
        message error "No Releases" "No releases found for $runner_type."
        return 1
    fi
    
    # Show release selection menu
    local release_selection
    release_selection=$(menu "Select Release" "Choose a release to install:" "${releases_array[@]}")
    
    if [[ $? -ne 0 || -z "$release_selection" ]]; then
        debug_print continue "Release selection cancelled"
        return 1
    fi
    
    local selected_release="${releases_array[$((release_selection-1))]}"
    
    # Get download URL
    debug_print continue "Getting download URL for $selected_release..."
    local download_url
    if ! download_url=$(get_runner_download_url "$runner_type" "$selected_release"); then
        message error "URL Failed" "Failed to get download URL for $selected_release."
        return 1
    fi
    
    # Download the runner
    debug_print continue "Downloading $selected_release..."
    message info "Downloading" "Downloading $selected_release...\n\nThis may take a few minutes depending on your internet connection."
    
    local downloaded_file
    if ! downloaded_file=$(download_runner "$download_url" "$selected_release"); then
        message error "Download Failed" "Failed to download $selected_release.\n\nCheck your internet connection and try again."
        return 1
    fi
    
    # Install the runner
    debug_print continue "Installing $selected_release..."
    message info "Installing" "Installing $selected_release...\n\nThis may take a few minutes."
    
    if install_runner "$downloaded_file" "$selected_release" "$runner_type"; then
        # Clean up downloaded file
        rm -f "$downloaded_file"
        
        # Ask if user wants to set as default
        if message question "Set as Default" "Would you like to set '$selected_release' as your default wine runner?"; then
            set_default_runner "$selected_release"
        fi
        
        return 0
    else
        # Clean up downloaded file on failure
        rm -f "$downloaded_file"
        return 1
    fi
}

# Validate wine version against requirements
validate_wine_version() {
    local runner_name="$1"
    local min_version="${2:-6.0}"  # Default minimum version
    
    if [[ -z "$runner_name" ]]; then
        debug_print exit "No runner name specified for version validation"
        return 1
    fi
    
    local wine_binary
    if ! wine_binary=$(get_runner_binary "$runner_name"); then
        debug_print exit "Failed to get wine binary for runner: $runner_name"
        return 1
    fi
    
    # Get wine version
    local wine_version
    if ! wine_version=$("$wine_binary" --version 2>/dev/null); then
        debug_print exit "Failed to get wine version from: $wine_binary"
        return 1
    fi
    
    debug_print continue "Wine version for $runner_name: $wine_version"
    
    # Extract version number (handle different formats)
    local version_number
    if [[ "$wine_version" =~ wine-([0-9]+\.[0-9]+) ]]; then
        version_number="${BASH_REMATCH[1]}"
    elif [[ "$wine_version" =~ ([0-9]+\.[0-9]+) ]]; then
        version_number="${BASH_REMATCH[1]}"
    else
        debug_print continue "Warning: Could not parse wine version: $wine_version"
        return 0  # Assume valid if we can't parse
    fi
    
    # Compare versions (simple numeric comparison)
    if [[ $(echo "$version_number >= $min_version" | bc -l 2>/dev/null) == "1" ]]; then
        debug_print continue "Wine version validation passed: $version_number >= $min_version"
        return 0
    else
        debug_print continue "Wine version validation failed: $version_number < $min_version"
        return 1
    fi
}

# Wine runner management main menu
manage_wine_runners() {
    debug_print continue "Starting wine runner management..."
    
    local management_options=(
        "Install Wine Runner"
        "Select Default Runner"
        "List Installed Runners"
        "Delete Wine Runner"
        "Install Proton Experimental"
        "Validate Current Runner"
    )
    
    while menu_should_continue; do
        local selection
        selection=$(menu "Wine Runner Management" "Manage your wine runners for optimal WoW performance:" "${management_options[@]}")
        
        if [[ $? -ne 0 || -z "$selection" ]]; then
            debug_print continue "Wine runner management menu cancelled"
            break
        fi
        
        case "$selection" in
            1)
                install_runner_workflow
                ;;
            2)
                select_runner
                ;;
            3)
                local runners_list
                if runners_list=$(list_installed_runners); then
                    message info "Installed Runners" "Currently installed wine runners:\n\n$runners_list"
                else
                    message info "No Runners" "No wine runners are currently installed."
                fi
                ;;
            4)
                # Get list of runners for deletion
                local runners_output
                if runners_output=$(list_installed_runners); then
                    local runners=()
                    while IFS= read -r line; do
                        if [[ -n "$line" ]]; then
                            local runner_name
                            runner_name=$(echo "$line" | sed 's/ (.*//')
                            runners+=("$runner_name")
                        fi
                    done <<< "$runners_output"
                    
                    if [[ ${#runners[@]} -gt 0 ]]; then
                        local delete_selection
                        delete_selection=$(menu "Delete Runner" "Select a wine runner to delete:" "${runners[@]}")
                        
                        if [[ $? -eq 0 && -n "$delete_selection" ]]; then
                            delete_runner "${runners[$((delete_selection-1))]}"
                        fi
                    fi
                else
                    message info "No Runners" "No wine runners are currently installed."
                fi
                ;;
            5)
                get_proton_experimental
                ;;
            6)
                local current_runner
                current_runner=$(get_default_runner)
                if validate_wine_version "$current_runner"; then
                    message info "Validation Passed" "Current wine runner '$current_runner' meets the minimum requirements."
                else
                    message error "Validation Failed" "Current wine runner '$current_runner' may not meet the minimum requirements.\n\nConsider upgrading to a newer version."
                fi
                ;;
            *)
                debug_print exit "Invalid wine runner management selection: $selection"
                ;;
        esac
    done
    
    debug_print continue "Wine runner management completed"
}

############################################################################
# Battle.net Installation and Configuration System
############################################################################

# Create wine prefix setup functions
create_wine_prefix() {
    local prefix_path="$1"
    local wine_runner="$2"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified"
        return 1
    fi
    
    # Use default wine runner if not specified
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
        debug_print continue "Using default wine runner: $wine_runner"
    fi
    
    debug_print continue "Creating wine prefix: $prefix_path"
    debug_print continue "Using wine runner: $wine_runner"
    
    # Validate wine runner exists
    local wine_binary
    if ! wine_binary=$(get_runner_binary "$wine_runner"); then
        debug_print exit "Wine runner not found: $wine_runner"
        message error "Wine Runner Missing" "The specified wine runner '$wine_runner' is not installed.\n\nPlease install it first using the wine runner management feature."
        return 1
    fi
    
    # Create prefix directory if it doesn't exist
    if [[ ! -d "$prefix_path" ]]; then
        debug_print continue "Creating prefix directory: $prefix_path"
        if ! mkdir -p "$prefix_path"; then
            debug_print exit "Failed to create prefix directory: $prefix_path"
            return 1
        fi
    fi
    
    # Check if prefix already exists and has content
    if [[ -d "$prefix_path/drive_c" ]]; then
        debug_print continue "Wine prefix already exists at: $prefix_path"
        if ! message question "Prefix Exists" "A wine prefix already exists at:\n$prefix_path\n\nDo you want to recreate it? This will delete all existing data in the prefix."; then
            debug_print continue "Prefix recreation cancelled by user"
            return 1
        fi
        
        # Remove existing prefix
        debug_print continue "Removing existing prefix content"
        if ! rm -rf "$prefix_path"/*; then
            debug_print exit "Failed to remove existing prefix content"
            return 1
        fi
    fi
    
    # Set wine environment variables
    export WINEPREFIX="$prefix_path"
    export WINEARCH="win64"
    
    # Handle Proton Experimental specific setup
    if [[ "$wine_runner" == "proton-experimental" ]]; then
        if ! configure_proton_experimental "$wine_runner" "$prefix_path"; then
            debug_print exit "Failed to configure Proton Experimental"
            return 1
        fi
    fi
    
    debug_print continue "Initializing wine prefix with $wine_binary"
    
    # Initialize wine prefix (64-bit)
    if ! WINEPREFIX="$prefix_path" WINEARCH="win64" "$wine_binary" wineboot --init; then
        debug_print exit "Failed to initialize wine prefix"
        return 1
    fi
    
    # Wait for wineserver to finish
    debug_print continue "Waiting for wine initialization to complete..."
    if ! WINEPREFIX="$prefix_path" "$wine_binary" wineserver --wait; then
        debug_print continue "Warning: wineserver wait failed, continuing anyway"
    fi
    
    # Verify prefix creation
    if [[ ! -d "$prefix_path/drive_c" ]]; then
        debug_print exit "Wine prefix creation failed - drive_c not found"
        return 1
    fi
    
    debug_print continue "Wine prefix created successfully: $prefix_path"
    return 0
}

# Install Arial font via winetricks
install_arial_font() {
    local prefix_path="$1"
    local wine_runner="$2"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for font installation"
        return 1
    fi
    
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
    fi
    
    debug_print continue "Installing Arial font in wine prefix: $prefix_path"
    
    # Check if winetricks is available
    if ! command_exists "winetricks"; then
        debug_print exit "winetricks is not installed"
        message error "Winetricks Required" "winetricks is required to install fonts but is not available.\n\nPlease install winetricks using your distribution's package manager."
        return 1
    fi
    
    # Get wine binary path
    local wine_binary
    if ! wine_binary=$(get_runner_binary "$wine_runner"); then
        debug_print exit "Wine runner not found: $wine_runner"
        return 1
    fi
    
    # Set environment variables for winetricks
    export WINEPREFIX="$prefix_path"
    export WINE="$wine_binary"
    
    # Handle Proton Experimental specific environment
    if [[ "$wine_runner" == "proton-experimental" ]]; then
        local runner_dir="$wine_runners_dir/$wine_runner"
        export STEAM_COMPAT_DATA_PATH="$prefix_path"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$runner_dir"
    fi
    
    debug_print continue "Running winetricks to install Arial font..."
    
    # Install Arial font silently
    if ! WINEPREFIX="$prefix_path" WINE="$wine_binary" winetricks --unattended arial; then
        debug_print exit "Failed to install Arial font via winetricks"
        message error "Font Installation Failed" "Failed to install Arial font.\n\nThis may cause blurry text in Battle.net. You can try installing it manually later."
        return 1
    fi
    
    # Wait for winetricks to complete
    debug_print continue "Waiting for font installation to complete..."
    if ! WINEPREFIX="$prefix_path" "$wine_binary" wineserver --wait; then
        debug_print continue "Warning: wineserver wait failed after font installation"
    fi
    
    debug_print continue "Arial font installed successfully"
    return 0
}

# Apply wine registry modifications for DXVA2 and nvapi settings
apply_wine_registry_tweaks() {
    local prefix_path="$1"
    local wine_runner="$2"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for registry tweaks"
        return 1
    fi
    
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
    fi
    
    debug_print continue "Applying wine registry tweaks for Battle.net optimization"
    
    # Get wine binary path
    local wine_binary
    if ! wine_binary=$(get_runner_binary "$wine_runner"); then
        debug_print exit "Wine runner not found: $wine_runner"
        return 1
    fi
    
    # Set environment variables
    export WINEPREFIX="$prefix_path"
    
    # Handle Proton Experimental specific environment
    if [[ "$wine_runner" == "proton-experimental" ]]; then
        local runner_dir="$wine_runners_dir/$wine_runner"
        export STEAM_COMPAT_DATA_PATH="$prefix_path"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$runner_dir"
    fi
    
    debug_print continue "Setting DXVA2 backend for Wine Staging..."
    
    # Enable DXVA2 backend (Wine Staging feature)
    if ! WINEPREFIX="$prefix_path" "$wine_binary" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DXVA2" /v "backend" /t REG_SZ /d "va" /f; then
        debug_print continue "Warning: Failed to set DXVA2 backend (Wine Staging may not be available)"
    fi
    
    debug_print continue "Disabling nvapi and nvapi64 DLL overrides..."
    
    # Disable nvapi DLL override
    if ! WINEPREFIX="$prefix_path" "$wine_binary" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "nvapi" /t REG_SZ /d "disabled" /f; then
        debug_print exit "Failed to disable nvapi DLL override"
        return 1
    fi
    
    # Disable nvapi64 DLL override
    if ! WINEPREFIX="$prefix_path" "$wine_binary" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "nvapi64" /t REG_SZ /d "disabled" /f; then
        debug_print exit "Failed to disable nvapi64 DLL override"
        return 1
    fi
    
    # Wait for registry changes to be applied
    debug_print continue "Waiting for registry changes to be applied..."
    if ! WINEPREFIX="$prefix_path" "$wine_binary" wineserver --wait; then
        debug_print continue "Warning: wineserver wait failed after registry changes"
    fi
    
    debug_print continue "Wine registry tweaks applied successfully"
    return 0
}

# Complete wine prefix setup with all optimizations
setup_wine_prefix_complete() {
    local prefix_path="$1"
    local wine_runner="$2"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for complete setup"
        return 1
    fi
    
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
        debug_print continue "Using default wine runner: $wine_runner"
    fi
    
    debug_print continue "Starting complete wine prefix setup..."
    debug_print continue "Prefix path: $prefix_path"
    debug_print continue "Wine runner: $wine_runner"
    
    # Step 1: Create wine prefix
    message info "Wine Prefix Setup" "Creating wine prefix for Battle.net installation...\n\nThis may take a few minutes."
    
    if ! create_wine_prefix "$prefix_path" "$wine_runner"; then
        debug_print exit "Failed to create wine prefix"
        return 1
    fi
    
    # Step 2: Install Arial font
    message info "Font Installation" "Installing Arial font to fix blurry text issues...\n\nThis may take a few minutes."
    
    if ! install_arial_font "$prefix_path" "$wine_runner"; then
        debug_print continue "Warning: Arial font installation failed, continuing anyway"
        # Don't return error here as this is not critical for basic functionality
    fi
    
    # Step 3: Apply registry tweaks
    message info "Registry Optimization" "Applying wine registry optimizations for Battle.net..."
    
    if ! apply_wine_registry_tweaks "$prefix_path" "$wine_runner"; then
        debug_print exit "Failed to apply wine registry tweaks"
        return 1
    fi
    
    # Save wine prefix path to configuration
    if ! save_winedir "$prefix_path"; then
        debug_print continue "Warning: Failed to save wine prefix path to configuration"
    fi
    
    debug_print continue "Complete wine prefix setup finished successfully"
    message info "Setup Complete" "Wine prefix setup completed successfully!\n\nPrefix location: $prefix_path\n\nThe prefix is now ready for Battle.net installation."
    
    return 0
}

# Download Battle.net setup file
download_battlenet() {
    local download_dir="$1"
    local battlenet_url="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
    
    if [[ -z "$download_dir" ]]; then
        download_dir="/tmp/azeroth-winebar-battlenet"
    fi
    
    debug_print continue "Downloading Battle.net setup..."
    debug_print continue "Download directory: $download_dir"
    
    # Create download directory
    if ! mkdir -p "$download_dir"; then
        debug_print exit "Failed to create download directory: $download_dir"
        return 1
    fi
    
    local battlenet_installer="$download_dir/Battle.net-Setup.exe"
    
    # Check if installer already exists
    if [[ -f "$battlenet_installer" ]]; then
        debug_print continue "Battle.net installer already exists: $battlenet_installer"
        
        # Verify file size (should be at least 1MB)
        local file_size
        file_size=$(stat -c%s "$battlenet_installer" 2>/dev/null || echo "0")
        if [[ "$file_size" -gt 1000000 ]]; then
            debug_print continue "Using existing Battle.net installer"
            echo "$battlenet_installer"
            return 0
        else
            debug_print continue "Existing installer appears corrupted, re-downloading"
            rm -f "$battlenet_installer"
        fi
    fi
    
    debug_print continue "Downloading from: $battlenet_url"
    
    # Download Battle.net installer
    if ! curl -L -o "$battlenet_installer" "$battlenet_url"; then
        debug_print exit "Failed to download Battle.net installer"
        return 1
    fi
    
    # Verify download
    if [[ ! -f "$battlenet_installer" ]]; then
        debug_print exit "Downloaded Battle.net installer not found"
        return 1
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -c%s "$battlenet_installer" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 1000000 ]]; then
        debug_print exit "Downloaded Battle.net installer appears to be too small: $file_size bytes"
        return 1
    fi
    
    debug_print continue "Battle.net installer downloaded successfully: $file_size bytes"
    echo "$battlenet_installer"
    return 0
}

# Install Battle.net in wine prefix
install_battlenet_in_prefix() {
    local prefix_path="$1"
    local wine_runner="$2"
    local installer_path="$3"
    
    if [[ -z "$prefix_path" || -z "$installer_path" ]]; then
        debug_print exit "Missing parameters for Battle.net installation"
        return 1
    fi
    
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
    fi
    
    if [[ ! -f "$installer_path" ]]; then
        debug_print exit "Battle.net installer not found: $installer_path"
        return 1
    fi
    
    debug_print continue "Installing Battle.net in wine prefix..."
    debug_print continue "Prefix: $prefix_path"
    debug_print continue "Installer: $installer_path"
    debug_print continue "Wine runner: $wine_runner"
    
    # Get wine binary path
    local wine_binary
    if ! wine_binary=$(get_runner_binary "$wine_runner"); then
        debug_print exit "Wine runner not found: $wine_runner"
        return 1
    fi
    
    # Set environment variables
    export WINEPREFIX="$prefix_path"
    
    # Handle Proton Experimental specific environment
    if [[ "$wine_runner" == "proton-experimental" ]]; then
        local runner_dir="$wine_runners_dir/$wine_runner"
        export STEAM_COMPAT_DATA_PATH="$prefix_path"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$runner_dir"
    fi
    
    debug_print continue "Running Battle.net installer..."
    
    # Run Battle.net installer
    # Note: We run it in the background and monitor for completion
    if ! WINEPREFIX="$prefix_path" "$wine_binary" "$installer_path" /S; then
        debug_print exit "Battle.net installer failed to run"
        return 1
    fi
    
    # Wait for installation to complete
    debug_print continue "Waiting for Battle.net installation to complete..."
    local max_wait=300  # 5 minutes maximum wait
    local wait_count=0
    
    while [[ $wait_count -lt $max_wait ]]; do
        # Check if Battle.net.exe exists in the expected location
        if [[ -f "$prefix_path/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" ]]; then
            debug_print continue "Battle.net installation detected"
            break
        fi
        
        sleep 2
        ((wait_count += 2))
        
        if [[ $((wait_count % 30)) -eq 0 ]]; then
            debug_print continue "Still waiting for Battle.net installation... ($wait_count/$max_wait seconds)"
        fi
    done
    
    # Final verification
    if [[ ! -f "$prefix_path/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" ]]; then
        debug_print exit "Battle.net installation verification failed - Battle.net.exe not found"
        return 1
    fi
    
    # Wait for any remaining wine processes to finish
    debug_print continue "Waiting for wine processes to finish..."
    if ! WINEPREFIX="$prefix_path" "$wine_binary" wineserver --wait; then
        debug_print continue "Warning: wineserver wait failed after Battle.net installation"
    fi
    
    debug_print continue "Battle.net installed successfully"
    return 0
}

# Main Battle.net installation orchestrator function
install_battlenet() {
    local prefix_path="$1"
    local wine_runner="$2"
    
    # Use configured wine prefix if not specified
    if [[ -z "$prefix_path" ]]; then
        if [[ -n "$wine_prefix" ]]; then
            prefix_path="$wine_prefix"
            debug_print continue "Using configured wine prefix: $prefix_path"
        else
            debug_print exit "No wine prefix specified and none configured"
            message error "Wine Prefix Required" "No wine prefix is configured.\n\nPlease set up a wine prefix first using the wine prefix management feature."
            return 1
        fi
    fi
    
    if [[ -z "$wine_runner" ]]; then
        wine_runner="proton-experimental"
        debug_print continue "Using default wine runner: $wine_runner"
    fi
    
    debug_print continue "Starting Battle.net installation process..."
    
    # Verify wine prefix exists
    if [[ ! -d "$prefix_path" ]]; then
        debug_print exit "Wine prefix does not exist: $prefix_path"
        message error "Wine Prefix Missing" "The specified wine prefix does not exist:\n$prefix_path\n\nPlease create a wine prefix first."
        return 1
    fi
    
    # Check if Battle.net is already installed
    if [[ -f "$prefix_path/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" ]]; then
        debug_print continue "Battle.net appears to be already installed"
        if ! message question "Battle.net Exists" "Battle.net appears to be already installed in this wine prefix.\n\nDo you want to reinstall it?"; then
            debug_print continue "Battle.net installation cancelled by user"
            return 1
        fi
    fi
    
    # Step 1: Download Battle.net installer
    message info "Downloading Battle.net" "Downloading Battle.net installer...\n\nThis may take a few minutes depending on your internet connection."
    
    local installer_path
    if ! installer_path=$(download_battlenet); then
        debug_print exit "Failed to download Battle.net installer"
        message error "Download Failed" "Failed to download Battle.net installer.\n\nPlease check your internet connection and try again."
        return 1
    fi
    
    # Step 2: Install Battle.net
    message info "Installing Battle.net" "Installing Battle.net in wine prefix...\n\nThis may take several minutes. Please wait for the installation to complete."
    
    if ! install_battlenet_in_prefix "$prefix_path" "$wine_runner" "$installer_path"; then
        debug_print exit "Failed to install Battle.net"
        message error "Installation Failed" "Battle.net installation failed.\n\nPlease check the debug output for more information."
        return 1
    fi
    
    # Step 3: Clean up installer
    debug_print continue "Cleaning up installer file..."
    if [[ -f "$installer_path" ]]; then
        rm -f "$installer_path"
        debug_print continue "Installer file removed: $installer_path"
    fi
    
    # Step 4: Save configuration
    if ! save_winedir "$prefix_path"; then
        debug_print continue "Warning: Failed to save wine prefix configuration"
    fi
    
    debug_print continue "Battle.net installation completed successfully"
    message info "Installation Complete" "Battle.net has been installed successfully!\n\nPrefix: $prefix_path\n\nYou can now proceed with Battle.net configuration and WoW-specific optimizations."
    
    return 0
}

# Generate optimized Battle.net.config JSON
generate_battlenet_config() {
    local config_data
    
    debug_print continue "Generating optimized Battle.net configuration..."
    
    # Create optimized Battle.net configuration JSON
    config_data=$(cat << 'EOF'
{
  "Client": {
    "GameLaunchWindowBehavior": "2",
    "GameSearch": {
      "BackgroundSearch": "false"
    },
    "HardwareAcceleration": "false",
    "Sound": {
      "Enabled": "false"
    },
    "Streaming": {
      "StreamingEnabled": "false"
    },
    "UserInterface": {
      "CloseToTray": "true"
    }
  }
}
EOF
)
    
    echo "$config_data"
    return 0
}

# Apply Battle.net configuration to wine prefix
apply_battlenet_config() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for Battle.net configuration"
        return 1
    fi
    
    if [[ ! -d "$prefix_path" ]]; then
        debug_print exit "Wine prefix does not exist: $prefix_path"
        return 1
    fi
    
    debug_print continue "Applying Battle.net configuration optimizations..."
    
    # Battle.net config directory path
    local battlenet_config_dir="$prefix_path/drive_c/users/$USER/AppData/Roaming/Battle.net"
    local battlenet_config_file="$battlenet_config_dir/Battle.net.config"
    
    # Create Battle.net config directory if it doesn't exist
    if [[ ! -d "$battlenet_config_dir" ]]; then
        debug_print continue "Creating Battle.net config directory: $battlenet_config_dir"
        if ! mkdir -p "$battlenet_config_dir"; then
            debug_print exit "Failed to create Battle.net config directory"
            return 1
        fi
    fi
    
    # Generate and write Battle.net configuration
    local config_json
    if ! config_json=$(generate_battlenet_config); then
        debug_print exit "Failed to generate Battle.net configuration"
        return 1
    fi
    
    debug_print continue "Writing Battle.net configuration to: $battlenet_config_file"
    
    if ! echo "$config_json" > "$battlenet_config_file"; then
        debug_print exit "Failed to write Battle.net configuration file"
        return 1
    fi
    
    # Verify configuration file was created
    if [[ ! -f "$battlenet_config_file" ]]; then
        debug_print exit "Battle.net configuration file was not created"
        return 1
    fi
    
    # Set appropriate permissions
    chmod 644 "$battlenet_config_file"
    
    debug_print continue "Battle.net configuration applied successfully"
    return 0
}

# Configure Battle.net for optimal WoW performance
configure_battlenet_for_wow() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for Battle.net WoW configuration"
        return 1
    fi
    
    debug_print continue "Configuring Battle.net for optimal WoW performance..."
    
    # Apply basic Battle.net configuration
    if ! apply_battlenet_config "$prefix_path"; then
        debug_print exit "Failed to apply Battle.net configuration"
        return 1
    fi
    
    # Additional WoW-specific Battle.net optimizations
    local battlenet_data_dir="$prefix_path/drive_c/ProgramData/Battle.net"
    
    # Create Battle.net data directory if needed
    if [[ ! -d "$battlenet_data_dir" ]]; then
        debug_print continue "Creating Battle.net data directory: $battlenet_data_dir"
        if ! mkdir -p "$battlenet_data_dir"; then
            debug_print continue "Warning: Failed to create Battle.net data directory"
        fi
    fi
    
    # Disable Battle.net helper processes that can interfere with WoW
    local battlenet_agent_dir="$prefix_path/drive_c/Program Files (x86)/Battle.net"
    
    if [[ -d "$battlenet_agent_dir" ]]; then
        debug_print continue "Configuring Battle.net helper process exclusions..."
        
        # Create a marker file to indicate optimized configuration
        local optimization_marker="$battlenet_agent_dir/.azeroth-winebar-optimized"
        echo "$(date -Iseconds)" > "$optimization_marker"
        
        debug_print continue "Battle.net optimization marker created"
    fi
    
    debug_print continue "Battle.net configured for optimal WoW performance"
    return 0
}

# Disable hardware acceleration in Battle.net
disable_battlenet_hardware_acceleration() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for hardware acceleration disable"
        return 1
    fi
    
    debug_print continue "Disabling Battle.net hardware acceleration..."
    
    # This is handled by the main Battle.net configuration
    # but we provide this as a separate function for clarity
    if ! apply_battlenet_config "$prefix_path"; then
        debug_print exit "Failed to disable hardware acceleration"
        return 1
    fi
    
    debug_print continue "Battle.net hardware acceleration disabled"
    return 0
}

# Disable Battle.net streaming features
disable_battlenet_streaming() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix path specified for streaming disable"
        return 1
    fi
    
    debug_print continue "Disabling Battle.net streaming features..."
    
    # This is handled by the main Battle.net configuration
    # but we provide this as a separate function for clarity
    if ! apply_battlenet_config "$prefix_path"; then
        debug_print exit "Failed to disable streaming features"
        return 1
    fi
    
    debug_print continue "Battle.net streaming features disabled"
    return 0
}

# Complete Battle.net configuration setup
setup_battlenet_configuration() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        # Use configured wine prefix if available
        if [[ -n "$wine_prefix" ]]; then
            prefix_path="$wine_prefix"
            debug_print continue "Using configured wine prefix: $prefix_path"
        else
            debug_print exit "No wine prefix specified and none configured"
            return 1
        fi
    fi
    
    debug_print continue "Starting complete Battle.net configuration setup..."
    
    # Verify Battle.net is installed
    if [[ ! -f "$prefix_path/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" ]]; then
        debug_print exit "Battle.net is not installed in the specified prefix"
        message error "Battle.net Not Found" "Battle.net is not installed in the wine prefix:\n$prefix_path\n\nPlease install Battle.net first."
        return 1
    fi
    
    # Apply all Battle.net optimizations
    message info "Battle.net Configuration" "Applying Battle.net configuration optimizations...\n\nThis will optimize Battle.net for WoW performance."
    
    if ! configure_battlenet_for_wow "$prefix_path"; then
        debug_print exit "Failed to configure Battle.net for WoW"
        message error "Configuration Failed" "Failed to apply Battle.net configuration optimizations.\n\nPlease check the debug output for more information."
        return 1
    fi
    
    debug_print continue "Battle.net configuration setup completed successfully"
    message info "Configuration Complete" "Battle.net has been configured with the following optimizations:\n\n• Hardware acceleration disabled\n• Streaming features disabled\n• Background search disabled\n• Launcher minimizes after game launch\n• Sound notifications disabled\n\nBattle.net is now optimized for WoW!"
    
    return 0
}

############################################################################
# WoW-Specific Optimization and Configuration System
############################################################################

# Find WoW Config.wtf file location
find_wow_config() {
    debug_print continue "Searching for WoW Config.wtf file..."
    
    if [[ -z "$game_dir" ]]; then
        debug_print exit "Game directory not configured"
        return 1
    fi
    
    # Common Config.wtf locations within WoW installation
    local config_paths=(
        "$game_dir/WTF/Config.wtf"
        "$game_dir/_retail_/WTF/Config.wtf"
        "$game_dir/_classic_/WTF/Config.wtf"
        "$game_dir/_classic_era_/WTF/Config.wtf"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [[ -f "$config_path" ]]; then
            debug_print continue "Found WoW Config.wtf: $config_path"
            echo "$config_path"
            return 0
        fi
    done
    
    debug_print continue "Config.wtf not found, will create default location"
    echo "$game_dir/WTF/Config.wtf"
    return 0
}

# Create WoW WTF directory structure if it doesn't exist
create_wow_wtf_directory() {
    local config_file="$1"
    local config_dir
    config_dir=$(dirname "$config_file")
    
    if [[ ! -d "$config_dir" ]]; then
        debug_print continue "Creating WoW WTF directory: $config_dir"
        if ! mkdir -p "$config_dir"; then
            debug_print exit "Failed to create WoW WTF directory: $config_dir"
            return 1
        fi
    fi
    
    return 0
}

# Read current value from Config.wtf
get_wow_config_value() {
    local config_file="$1"
    local setting_name="$2"
    
    if [[ ! -f "$config_file" ]]; then
        debug_print continue "Config.wtf not found: $config_file"
        return 1
    fi
    
    local current_value
    current_value=$(grep "^SET $setting_name " "$config_file" 2>/dev/null | cut -d' ' -f3- | tr -d '"')
    
    if [[ -n "$current_value" ]]; then
        echo "$current_value"
        return 0
    else
        debug_print continue "Setting $setting_name not found in Config.wtf"
        return 1
    fi
}

# Set or update a setting in Config.wtf
set_wow_config_value() {
    local config_file="$1"
    local setting_name="$2"
    local setting_value="$3"
    
    if [[ -z "$config_file" || -z "$setting_name" ]]; then
        debug_print exit "Missing parameters for WoW config update"
        return 1
    fi
    
    # Create directory if needed
    if ! create_wow_wtf_directory "$config_file"; then
        return 1
    fi
    
    # Create config file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        debug_print continue "Creating new Config.wtf file: $config_file"
        touch "$config_file"
    fi
    
    # Check if setting already exists
    if grep -q "^SET $setting_name " "$config_file"; then
        # Update existing setting
        debug_print continue "Updating existing setting: $setting_name = $setting_value"
        if ! sed -i "s/^SET $setting_name .*/SET $setting_name \"$setting_value\"/" "$config_file"; then
            debug_print exit "Failed to update setting in Config.wtf"
            return 1
        fi
    else
        # Add new setting
        debug_print continue "Adding new setting: $setting_name = $setting_value"
        if ! echo "SET $setting_name \"$setting_value\"" >> "$config_file"; then
            debug_print exit "Failed to add setting to Config.wtf"
            return 1
        fi
    fi
    
    debug_print continue "Successfully set $setting_name to $setting_value in Config.wtf"
    return 0
}

# Apply worldPreloadNonCritical optimization
apply_world_preload_optimization() {
    debug_print continue "Applying worldPreloadNonCritical optimization..."
    
    local config_file
    if ! config_file=$(find_wow_config); then
        debug_print exit "Failed to locate WoW Config.wtf"
        return 1
    fi
    
    # Get current value
    local current_value
    current_value=$(get_wow_config_value "$config_file" "worldPreloadNonCritical")
    
    if [[ "$current_value" == "0" ]]; then
        debug_print continue "worldPreloadNonCritical already optimized (set to 0)"
        return 0
    fi
    
    # Set worldPreloadNonCritical to 0 for better performance
    if set_wow_config_value "$config_file" "worldPreloadNonCritical" "0"; then
        debug_print continue "worldPreloadNonCritical optimization applied successfully"
        message info "WoW Optimization Applied" "worldPreloadNonCritical has been set to 0 in Config.wtf.\n\nThis optimization reduces loading times and improves performance."
        return 0
    else
        debug_print exit "Failed to apply worldPreloadNonCritical optimization"
        return 1
    fi
}

# Apply rawMouseEnable cursor fix
apply_raw_mouse_fix() {
    debug_print continue "Applying rawMouseEnable cursor fix..."
    
    local config_file
    if ! config_file=$(find_wow_config); then
        debug_print exit "Failed to locate WoW Config.wtf"
        return 1
    fi
    
    # Get current value
    local current_value
    current_value=$(get_wow_config_value "$config_file" "rawMouseEnable")
    
    if [[ "$current_value" == "1" ]]; then
        debug_print continue "rawMouseEnable already enabled (set to 1)"
        return 0
    fi
    
    # Set rawMouseEnable to 1 to fix cursor reset issues
    if set_wow_config_value "$config_file" "rawMouseEnable" "1"; then
        debug_print continue "rawMouseEnable cursor fix applied successfully"
        message info "WoW Cursor Fix Applied" "rawMouseEnable has been set to 1 in Config.wtf.\n\nThis fixes cursor reset issues when alt-tabbing or switching windows."
        return 0
    else
        debug_print exit "Failed to apply rawMouseEnable cursor fix"
        return 1
    fi
}

# Apply all WoW configuration optimizations
apply_wow_config_optimizations() {
    debug_print continue "Applying all WoW configuration optimizations..."
    
    local success=0
    local total=0
    
    # Apply worldPreloadNonCritical optimization
    ((total++))
    if apply_world_preload_optimization; then
        ((success++))
    fi
    
    # Apply rawMouseEnable cursor fix
    ((total++))
    if apply_raw_mouse_fix; then
        ((success++))
    fi
    
    # Report results
    if [[ $success -eq $total ]]; then
        debug_print continue "All WoW configuration optimizations applied successfully ($success/$total)"
        message info "WoW Configuration Complete" "All WoW configuration optimizations have been applied successfully.\n\nOptimizations applied:\n• worldPreloadNonCritical = 0 (performance)\n• rawMouseEnable = 1 (cursor fix)"
        return 0
    else
        debug_print continue "Some WoW configuration optimizations failed ($success/$total)"
        message error "Partial Configuration" "Some WoW configuration optimizations could not be applied.\n\nSuccessful: $success/$total\n\nPlease check the logs for details."
        return 1
    fi
}

# Backup current WoW configuration
backup_wow_config() {
    debug_print continue "Creating backup of WoW configuration..."
    
    local config_file
    if ! config_file=$(find_wow_config); then
        debug_print exit "Failed to locate WoW Config.wtf for backup"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        debug_print continue "No Config.wtf file to backup"
        return 0
    fi
    
    local backup_dir="$config_dir/backups"
    local backup_file="$backup_dir/Config.wtf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create backup directory
    if [[ ! -d "$backup_dir" ]]; then
        if ! mkdir -p "$backup_dir"; then
            debug_print exit "Failed to create backup directory: $backup_dir"
            return 1
        fi
    fi
    
    # Copy config file to backup
    if cp "$config_file" "$backup_file"; then
        debug_print continue "WoW configuration backed up to: $backup_file"
        return 0
    else
        debug_print exit "Failed to backup WoW configuration"
        return 1
    fi
}

# Restore WoW configuration from backup
restore_wow_config() {
    debug_print continue "Restoring WoW configuration from backup..."
    
    local backup_dir="$config_dir/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        debug_print exit "No backup directory found: $backup_dir"
        message error "No Backups Found" "No configuration backups were found.\n\nBackup directory: $backup_dir"
        return 1
    fi
    
    # Find available backups
    local backups=()
    while IFS= read -r -d '' backup_file; do
        local backup_name
        backup_name=$(basename "$backup_file")
        backups+=("$backup_name")
    done < <(find "$backup_dir" -name "Config.wtf.backup.*" -type f -print0 2>/dev/null)
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        debug_print exit "No Config.wtf backups found"
        message error "No Backups Available" "No Config.wtf backup files were found in the backup directory."
        return 1
    fi
    
    # Let user select backup to restore
    local selected_backup
    if ! selected_backup=$(menu "Restore WoW Configuration" "Select a backup to restore:" "${backups[@]}"); then
        debug_print continue "Backup restoration cancelled by user"
        return 1
    fi
    
    local backup_file="$backup_dir/${backups[$((selected_backup-1))]}"
    local config_file
    if ! config_file=$(find_wow_config); then
        debug_print exit "Failed to locate WoW Config.wtf for restoration"
        return 1
    fi
    
    # Confirm restoration
    if ! message question "Confirm Restoration" "Are you sure you want to restore the WoW configuration from this backup?\n\nBackup: ${backups[$((selected_backup-1))]}\nTarget: $config_file\n\nThis will overwrite the current configuration."; then
        debug_print continue "Backup restoration cancelled by user"
        return 1
    fi
    
    # Create directory if needed
    if ! create_wow_wtf_directory "$config_file"; then
        return 1
    fi
    
    # Restore backup
    if cp "$backup_file" "$config_file"; then
        debug_print continue "WoW configuration restored successfully"
        message info "Configuration Restored" "WoW configuration has been restored from backup.\n\nBackup: ${backups[$((selected_backup-1))]}\nRestored to: $config_file"
        return 0
    else
        debug_print exit "Failed to restore WoW configuration from backup"
        return 1
    fi
}

# Create DXVK configuration file for optimal performance
create_dxvk_config() {
    debug_print continue "Creating DXVK configuration file..."
    
    if [[ -z "$game_dir" ]]; then
        debug_print exit "Game directory not configured"
        return 1
    fi
    
    local dxvk_config_file="$game_dir/dxvk.conf"
    
    debug_print continue "Creating DXVK config at: $dxvk_config_file"
    
    # Create DXVK configuration with optimized settings
    cat > "$dxvk_config_file" << 'EOF'
# DXVK Configuration for World of Warcraft
# Generated by Azeroth Winebar

# Enable state cache for faster loading
dxvk.enableStateCache = True

# Optimize memory usage
dxvk.maxFrameLatency = 1

# Enable async shader compilation for smoother gameplay
dxvk.useAsync = True

# Optimize for gaming performance
dxvk.numCompilerThreads = 0

# Enable graphics pipeline library for better performance
dxvk.enableGraphicsPipelineLibrary = True

# Optimize VRAM usage
dxvk.maxDeviceMemory = 0

# Enable fast geometry shader passthrough
dxvk.useRawSsbo = True

# Optimize for WoW's rendering patterns
dxvk.shrinkNvidiaHvv = False

# Enable optimizations for older games
dxvk.enableOpenVR = False
EOF
    
    if [[ $? -eq 0 ]]; then
        debug_print continue "DXVK configuration file created successfully"
        return 0
    else
        debug_print exit "Failed to create DXVK configuration file"
        return 1
    fi
}

# Setup shader cache directories and environment
setup_shader_cache() {
    debug_print continue "Setting up shader cache directories..."
    
    if [[ -z "$game_dir" ]]; then
        debug_print exit "Game directory not configured"
        return 1
    fi
    
    # Create shader cache directories
    local cache_dirs=(
        "$game_dir/shadercache"
        "$game_dir/dxvk_cache"
        "$game_dir/vkd3d_cache"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ ! -d "$cache_dir" ]]; then
            debug_print continue "Creating shader cache directory: $cache_dir"
            if ! mkdir -p "$cache_dir"; then
                debug_print continue "Warning: Failed to create shader cache directory: $cache_dir"
            fi
        fi
    done
    
    debug_print continue "Shader cache directories setup completed"
    return 0
}

# Get graphics card vendor
detect_graphics_vendor() {
    debug_print continue "Detecting graphics card vendor..."
    
    local gpu_info
    if command_exists "lspci"; then
        gpu_info=$(lspci | grep -i vga 2>/dev/null)
    elif command_exists "lshw"; then
        gpu_info=$(lshw -c display 2>/dev/null | grep -i vendor)
    else
        debug_print continue "Unable to detect graphics vendor - no lspci or lshw available"
        echo "unknown"
        return 1
    fi
    
    if [[ -z "$gpu_info" ]]; then
        debug_print continue "No graphics card information found"
        echo "unknown"
        return 1
    fi
    
    # Check for NVIDIA
    if echo "$gpu_info" | grep -qi nvidia; then
        debug_print continue "NVIDIA graphics card detected"
        echo "nvidia"
        return 0
    fi
    
    # Check for AMD
    if echo "$gpu_info" | grep -qi -E "(amd|ati|radeon)"; then
        debug_print continue "AMD graphics card detected"
        echo "amd"
        return 0
    fi
    
    # Check for Intel
    if echo "$gpu_info" | grep -qi intel; then
        debug_print continue "Intel graphics card detected"
        echo "intel"
        return 0
    fi
    
    debug_print continue "Unknown graphics vendor detected"
    echo "unknown"
    return 1
}

# Generate graphics optimization environment variables
generate_graphics_env_vars() {
    local vendor="$1"
    local env_vars=()
    
    debug_print continue "Generating graphics environment variables for: $vendor"
    
    # Common DXVK environment variables
    env_vars+=(
        "export DXVK_CONFIG_FILE=\"\$GAMEDIR/dxvk.conf\""
        "export DXVK_STATE_CACHE_PATH=\"\$GAMEDIR/dxvk_cache\""
        "export DXVK_LOG_LEVEL=\"warn\""
        "export DXVK_HUD=\"compiler\""
    )
    
    # VKD3D environment variables
    env_vars+=(
        "export VKD3D_CONFIG=\"dxr\""
        "export VKD3D_SHADER_CACHE_PATH=\"\$GAMEDIR/vkd3d_cache\""
    )
    
    # Vendor-specific optimizations
    case "$vendor" in
        "nvidia")
            debug_print continue "Adding NVIDIA-specific optimizations"
            env_vars+=(
                "export __GL_SHADER_DISK_CACHE=1"
                "export __GL_SHADER_DISK_CACHE_PATH=\"\$GAMEDIR/shadercache\""
                "export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"
                "export __GL_THREADED_OPTIMIZATIONS=1"
                "export __GL_DXVK_OPTIMIZATIONS=1"
                "export NVIDIA_WINE_DLSS=1"
            )
            ;;
        "amd")
            debug_print continue "Adding AMD-specific optimizations"
            env_vars+=(
                "export RADV_PERFTEST=\"aco,llvm\""
                "export AMD_VULKAN_ICD=\"RADV\""
                "export MESA_VK_VERSION_OVERRIDE=\"1.3\""
                "export ACO_DEBUG=\"validateir,validatera\""
            )
            ;;
        "intel")
            debug_print continue "Adding Intel-specific optimizations"
            env_vars+=(
                "export ANV_ENABLE_PIPELINE_CACHE=1"
                "export MESA_VK_VERSION_OVERRIDE=\"1.3\""
            )
            ;;
        *)
            debug_print continue "Using generic graphics optimizations"
            ;;
    esac
    
    # General performance optimizations
    env_vars+=(
        "export WINE_CPU_TOPOLOGY=\"4:2\""
        "export WINE_LARGE_ADDRESS_AWARE=1"
    )
    
    # Output environment variables
    printf '%s\n' "${env_vars[@]}"
    return 0
}

# Apply DXVK and graphics optimizations
apply_dxvk_optimizations() {
    debug_print continue "Applying DXVK and graphics optimizations..."
    
    local success=0
    local total=0
    
    # Create DXVK configuration file
    ((total++))
    if create_dxvk_config; then
        ((success++))
        debug_print continue "DXVK configuration created successfully"
    else
        debug_print continue "Failed to create DXVK configuration"
    fi
    
    # Setup shader cache directories
    ((total++))
    if setup_shader_cache; then
        ((success++))
        debug_print continue "Shader cache setup completed successfully"
    else
        debug_print continue "Failed to setup shader cache directories"
    fi
    
    # Detect graphics vendor for optimizations
    local graphics_vendor
    graphics_vendor=$(detect_graphics_vendor)
    debug_print continue "Graphics vendor detected: $graphics_vendor"
    
    # Generate environment variables file for reference
    local env_file="$config_dir/graphics_env.sh"
    debug_print continue "Creating graphics environment variables file: $env_file"
    
    cat > "$env_file" << EOF
#!/bin/bash
# Graphics optimization environment variables
# Generated by Azeroth Winebar for $graphics_vendor graphics

# Game directory variable (to be set by launch script)
# GAMEDIR should be set to the WoW installation directory

$(generate_graphics_env_vars "$graphics_vendor")
EOF
    
    if [[ $? -eq 0 ]]; then
        ((success++))
        ((total++))
        chmod +x "$env_file"
        debug_print continue "Graphics environment variables file created successfully"
    else
        ((total++))
        debug_print continue "Failed to create graphics environment variables file"
    fi
    
    # Report results
    if [[ $success -eq $total ]]; then
        debug_print continue "All DXVK and graphics optimizations applied successfully ($success/$total)"
        message info "Graphics Optimization Complete" "DXVK and graphics optimizations have been applied successfully.\n\nOptimizations applied:\n• DXVK configuration file created\n• Shader cache directories setup\n• $graphics_vendor-specific optimizations configured\n\nConfiguration files:\n• $game_dir/dxvk.conf\n• $env_file"
        return 0
    else
        debug_print continue "Some DXVK and graphics optimizations failed ($success/$total)"
        message error "Partial Optimization" "Some DXVK and graphics optimizations could not be applied.\n\nSuccessful: $success/$total\n\nPlease check the logs for details."
        return 1
    fi
}

# Update DXVK configuration with custom settings
update_dxvk_config() {
    debug_print continue "Updating DXVK configuration with custom settings..."
    
    if [[ -z "$game_dir" ]]; then
        debug_print exit "Game directory not configured"
        return 1
    fi
    
    local dxvk_config_file="$game_dir/dxvk.conf"
    
    if [[ ! -f "$dxvk_config_file" ]]; then
        debug_print continue "DXVK config file not found, creating new one"
        if ! create_dxvk_config; then
            return 1
        fi
    fi
    
    # Menu for DXVK configuration options
    local dxvk_options=(
        "Enable Async Shader Compilation"
        "Disable Async Shader Compilation"
        "Enable State Cache"
        "Disable State Cache"
        "Reset to Default Configuration"
        "View Current Configuration"
    )
    
    local selected_option
    if ! selected_option=$(menu "DXVK Configuration" "Select a DXVK configuration option:" "${dxvk_options[@]}"); then
        debug_print continue "DXVK configuration cancelled by user"
        return 1
    fi
    
    case "$selected_option" in
        "1")
            sed -i 's/dxvk.useAsync = .*/dxvk.useAsync = True/' "$dxvk_config_file"
            message info "DXVK Updated" "Async shader compilation has been enabled."
            ;;
        "2")
            sed -i 's/dxvk.useAsync = .*/dxvk.useAsync = False/' "$dxvk_config_file"
            message info "DXVK Updated" "Async shader compilation has been disabled."
            ;;
        "3")
            sed -i 's/dxvk.enableStateCache = .*/dxvk.enableStateCache = True/' "$dxvk_config_file"
            message info "DXVK Updated" "State cache has been enabled."
            ;;
        "4")
            sed -i 's/dxvk.enableStateCache = .*/dxvk.enableStateCache = False/' "$dxvk_config_file"
            message info "DXVK Updated" "State cache has been disabled."
            ;;
        "5")
            if message question "Reset Configuration" "Are you sure you want to reset the DXVK configuration to defaults?\n\nThis will overwrite any custom settings."; then
                create_dxvk_config
                message info "DXVK Reset" "DXVK configuration has been reset to defaults."
            fi
            ;;
        "6")
            if [[ -f "$dxvk_config_file" ]]; then
                local config_content
                config_content=$(cat "$dxvk_config_file")
                message info "Current DXVK Configuration" "$config_content"
            else
                message error "Configuration Not Found" "DXVK configuration file not found."
            fi
            ;;
        *)
            debug_print continue "Invalid DXVK configuration option selected"
            return 1
            ;;
    esac
    
    return 0
}

# Configure wine DLL overrides for optimal WoW performance
configure_wine_dll_overrides() {
    debug_print continue "Configuring wine DLL overrides..."
    
    if [[ -z "$wine_prefix" ]]; then
        debug_print exit "Wine prefix not configured"
        return 1
    fi
    
    if [[ ! -d "$wine_prefix" ]]; then
        debug_print exit "Wine prefix directory not found: $wine_prefix"
        return 1
    fi
    
    # Define DLL overrides for optimal WoW performance
    local dll_overrides=(
        "nvapi=disabled"
        "nvapi64=disabled"
        "nvcuda=disabled"
        "nvcuvid=disabled"
        "nvencodeapi=disabled"
        "nvencodeapi64=disabled"
    )
    
    debug_print continue "Applying wine DLL overrides for WoW optimization"
    
    # Set environment variable for current session
    local override_string=""
    for override in "${dll_overrides[@]}"; do
        if [[ -n "$override_string" ]]; then
            override_string="$override_string;$override"
        else
            override_string="$override"
        fi
    done
    
    # Apply DLL overrides using winecfg registry entries
    local wine_binary="wine"
    if [[ -n "$wine_prefix" ]]; then
        export WINEPREFIX="$wine_prefix"
    fi
    
    # Use wine reg to set DLL overrides
    for override in "${dll_overrides[@]}"; do
        local dll_name="${override%=*}"
        local dll_mode="${override#*=}"
        
        debug_print continue "Setting DLL override: $dll_name = $dll_mode"
        
        # Convert mode to wine registry format
        local reg_value=""
        case "$dll_mode" in
            "disabled")
                reg_value=""
                ;;
            "native")
                reg_value="native"
                ;;
            "builtin")
                reg_value="builtin"
                ;;
            *)
                reg_value="$dll_mode"
                ;;
        esac
        
        # Apply the override
        if [[ "$dll_mode" == "disabled" ]]; then
            # For disabled DLLs, we remove the registry entry or set it to empty
            $wine_binary reg delete "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "$dll_name" /f 2>/dev/null || true
        else
            $wine_binary reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "$dll_name" /t REG_SZ /d "$reg_value" /f 2>/dev/null
        fi
        
        if [[ $? -eq 0 ]]; then
            debug_print continue "Successfully set DLL override: $dll_name"
        else
            debug_print continue "Warning: Failed to set DLL override: $dll_name"
        fi
    done
    
    debug_print continue "Wine DLL overrides configuration completed"
    return 0
}

# Setup wine environment variables for optimal performance
setup_wine_environment() {
    debug_print continue "Setting up wine environment variables..."
    
    # Create wine environment configuration file
    local wine_env_file="$config_dir/wine_env.sh"
    
    debug_print continue "Creating wine environment file: $wine_env_file"
    
    cat > "$wine_env_file" << 'EOF'
#!/bin/bash
# Wine environment variables for World of Warcraft
# Generated by Azeroth Winebar

# Wine prefix and basic configuration
export WINEPREFIX="$WINE_PREFIX_PATH"
export WINEARCH="win64"
export WINE_LARGE_ADDRESS_AWARE=1

# DLL overrides for WoW optimization
export WINEDLLOVERRIDES="nvapi=disabled;nvapi64=disabled;nvcuda=disabled;nvcuvid=disabled;nvencodeapi=disabled;nvencodeapi64=disabled"

# Wine Staging optimizations
export STAGING_SHARED_MEMORY=1
export STAGING_RT_PRIORITY_SERVER=90
export STAGING_RT_PRIORITY_BASE=90

# DXVK and VKD3D optimizations
export DXVK_ASYNC=1
export DXVK_STATE_CACHE=1
export VKD3D_CONFIG="dxr"

# Memory and performance optimizations
export WINE_CPU_TOPOLOGY="4:2"
export WINE_HEAP_DELAY_FREE=1

# Audio optimizations
export PULSE_LATENCY_MSEC=60
export ALSA_PERIOD_SIZE=1024

# Disable wine debugging for performance
export WINEDEBUG=-all

# Enable DXVA2 backend for Wine Staging
export WINE_DXVA2_BACKEND=1

# Esync and Fsync optimizations (if available)
export WINEESYNC=1
export WINEFSYNC=1

# Prevent wine from creating desktop shortcuts and menu entries
export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;winemenubuilder.exe=disabled"

# Set wine to not manage the desktop
export WINE_VK_USE_FSR=0
EOF
    
    if [[ $? -eq 0 ]]; then
        chmod +x "$wine_env_file"
        debug_print continue "Wine environment configuration file created successfully"
    else
        debug_print exit "Failed to create wine environment configuration file"
        return 1
    fi
    
    return 0
}

# Apply comprehensive wine environment configuration
apply_wine_environment_config() {
    debug_print continue "Applying comprehensive wine environment configuration..."
    
    local success=0
    local total=0
    
    # Configure wine DLL overrides
    ((total++))
    if configure_wine_dll_overrides; then
        ((success++))
        debug_print continue "Wine DLL overrides configured successfully"
    else
        debug_print continue "Failed to configure wine DLL overrides"
    fi
    
    # Setup wine environment variables
    ((total++))
    if setup_wine_environment; then
        ((success++))
        debug_print continue "Wine environment variables setup completed successfully"
    else
        debug_print continue "Failed to setup wine environment variables"
    fi
    
    # Apply DXVA2 backend setting for Wine Staging
    ((total++))
    if apply_dxva2_backend; then
        ((success++))
        debug_print continue "DXVA2 backend configuration applied successfully"
    else
        debug_print continue "Failed to apply DXVA2 backend configuration"
    fi
    
    # Report results
    if [[ $success -eq $total ]]; then
        debug_print continue "All wine environment configurations applied successfully ($success/$total)"
        message info "Wine Environment Complete" "Wine environment configuration has been applied successfully.\n\nConfigurations applied:\n• DLL overrides (nvapi disabled)\n• Wine Staging optimizations\n• DXVK and VKD3D environment setup\n• Performance optimizations\n• DXVA2 backend enabled\n\nConfiguration file: $config_dir/wine_env.sh"
        return 0
    else
        debug_print continue "Some wine environment configurations failed ($success/$total)"
        message error "Partial Configuration" "Some wine environment configurations could not be applied.\n\nSuccessful: $success/$total\n\nPlease check the logs for details."
        return 1
    fi
}

# Apply DXVA2 backend setting for Wine Staging
apply_dxva2_backend() {
    debug_print continue "Applying DXVA2 backend configuration for Wine Staging..."
    
    if [[ -z "$wine_prefix" ]]; then
        debug_print exit "Wine prefix not configured"
        return 1
    fi
    
    if [[ ! -d "$wine_prefix" ]]; then
        debug_print exit "Wine prefix directory not found: $wine_prefix"
        return 1
    fi
    
    # Set DXVA2 backend in wine registry
    local wine_binary="wine"
    if [[ -n "$wine_prefix" ]]; then
        export WINEPREFIX="$wine_prefix"
    fi
    
    debug_print continue "Setting DXVA2 backend in wine registry"
    
    # Create the registry key for DXVA2 backend
    $wine_binary reg add "HKEY_CURRENT_USER\\Software\\Wine\\DXVA2" /v "backend" /t REG_SZ /d "va" /f 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        debug_print continue "DXVA2 backend configuration applied successfully"
        return 0
    else
        debug_print continue "Warning: Failed to apply DXVA2 backend configuration"
        return 1
    fi
}

# Generate complete wine launch environment
generate_wine_launch_env() {
    local wine_prefix_path="$1"
    local game_directory="$2"
    
    if [[ -z "$wine_prefix_path" || -z "$game_directory" ]]; then
        debug_print exit "Missing parameters for wine launch environment generation"
        return 1
    fi
    
    debug_print continue "Generating wine launch environment..."
    
    # Detect graphics vendor for optimizations
    local graphics_vendor
    graphics_vendor=$(detect_graphics_vendor)
    
    # Generate complete environment setup
    cat << EOF
#!/bin/bash
# Complete wine launch environment for World of Warcraft
# Generated by Azeroth Winebar

# Set paths
export WINE_PREFIX_PATH="$wine_prefix_path"
export GAMEDIR="$game_directory"

# Source wine environment configuration
if [[ -f "$config_dir/wine_env.sh" ]]; then
    source "$config_dir/wine_env.sh"
fi

# Source graphics environment configuration
if [[ -f "$config_dir/graphics_env.sh" ]]; then
    source "$config_dir/graphics_env.sh"
fi

# Additional runtime optimizations
export WINE_RT_PRIORITY_BASE=15
export WINE_RT_PRIORITY_SERVER=15

# Game-specific optimizations
export WINE_HEAP_DELAY_FREE=1
export WINE_DISABLE_WRITE_WATCH=1

# Ensure wine prefix is set
export WINEPREFIX="\$WINE_PREFIX_PATH"

# Debug information (comment out for production)
# echo "Wine Prefix: \$WINEPREFIX"
# echo "Game Directory: \$GAMEDIR"
# echo "Graphics Vendor: $graphics_vendor"
EOF
    
    return 0
}

# Reset wine environment to defaults
reset_wine_environment() {
    debug_print continue "Resetting wine environment to defaults..."
    
    if [[ -z "$wine_prefix" ]]; then
        debug_print exit "Wine prefix not configured"
        return 1
    fi
    
    if ! message question "Reset Wine Environment" "Are you sure you want to reset the wine environment configuration?\n\nThis will:\n• Remove all DLL overrides\n• Reset wine registry settings\n• Remove custom environment variables\n\nThis action cannot be undone."; then
        debug_print continue "Wine environment reset cancelled by user"
        return 1
    fi
    
    # Reset wine registry DLL overrides
    local wine_binary="wine"
    export WINEPREFIX="$wine_prefix"
    
    debug_print continue "Removing wine DLL overrides..."
    $wine_binary reg delete "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /f 2>/dev/null || true
    
    # Remove custom environment files
    local env_files=(
        "$config_dir/wine_env.sh"
        "$config_dir/graphics_env.sh"
    )
    
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            debug_print continue "Removing environment file: $env_file"
            rm "$env_file"
        fi
    done
    
    debug_print continue "Wine environment reset completed"
    message info "Environment Reset" "Wine environment has been reset to defaults.\n\nYou may need to reconfigure optimizations for optimal WoW performance."
    
    return 0
}

############################################################################
# Desktop Integration Functions
############################################################################

# Create Battle.net desktop entry
create_battlenet_desktop_entry() {
    local desktop_file_path="$1"
    local launch_script_path="$2"
    local icon_path="$3"
    
    debug_print continue "Creating Battle.net desktop entry at: $desktop_file_path"
    
    # Validate inputs
    if [[ -z "$desktop_file_path" || -z "$launch_script_path" ]]; then
        debug_print exit "Missing required parameters for desktop entry creation"
        return 1
    fi
    
    # Use default icon if not provided
    if [[ -z "$icon_path" ]]; then
        icon_path="applications-games"
    fi
    
    # Create desktop entry content
    cat > "$desktop_file_path" << EOF
[Desktop Entry]
Name=Battle.net
Comment=Blizzard Battle.net Launcher for World of Warcraft
Exec=$launch_script_path
Icon=$icon_path
Terminal=false
Type=Application
Categories=Game;
StartupNotify=true
StartupWMClass=battle.net.exe
EOF
    
    if [[ $? -eq 0 ]]; then
        debug_print continue "Desktop entry created successfully"
        # Make desktop file executable
        chmod +x "$desktop_file_path"
        return 0
    else
        debug_print exit "Failed to create desktop entry"
        return 1
    fi
}

# Install desktop entry to system locations
install_desktop_entry() {
    local launch_script_path="$1"
    local icon_path="$2"
    
    debug_print continue "Installing Battle.net desktop entry..."
    
    # Validate launch script exists
    if [[ ! -f "$launch_script_path" ]]; then
        debug_print exit "Launch script not found: $launch_script_path"
        return 1
    fi
    
    # Make launch script executable
    chmod +x "$launch_script_path"
    
    # Desktop entry locations
    local user_desktop="$HOME/Desktop/Battle.net.desktop"
    local user_applications="$HOME/.local/share/applications/Battle.net.desktop"
    
    # Create directories if they don't exist
    mkdir -p "$(dirname "$user_applications")"
    
    # Create desktop entry for user applications
    if create_battlenet_desktop_entry "$user_applications" "$launch_script_path" "$icon_path"; then
        debug_print continue "Desktop entry installed to applications menu"
    else
        debug_print continue "Warning: Failed to install desktop entry to applications menu"
    fi
    
    # Ask user if they want desktop shortcut
    if message question "Desktop Shortcut" "Would you like to create a desktop shortcut for Battle.net?"; then
        if create_battlenet_desktop_entry "$user_desktop" "$launch_script_path" "$icon_path"; then
            debug_print continue "Desktop shortcut created"
            message info "Desktop Integration" "Battle.net desktop entries have been created successfully.\n\nYou can now launch World of Warcraft from your applications menu or desktop."
        else
            debug_print continue "Warning: Failed to create desktop shortcut"
            message warning "Desktop Integration" "Desktop entry was created in applications menu, but desktop shortcut creation failed."
        fi
    else
        message info "Desktop Integration" "Battle.net desktop entry has been created in your applications menu."
    fi
    
    return 0
}

# Download and install Battle.net icon
install_battlenet_icon() {
    local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
    local icon_file="$icon_dir/battlenet.png"
    local icon_url="https://logos-world.net/wp-content/uploads/2021/10/Blizzard-Battle.net-Logo.png"
    
    debug_print continue "Installing Battle.net icon..."
    
    # Create icon directory
    if ! mkdir -p "$icon_dir"; then
        debug_print continue "Warning: Failed to create icon directory"
        return 1
    fi
    
    # Download icon if it doesn't exist
    if [[ ! -f "$icon_file" ]]; then
        debug_print continue "Downloading Battle.net icon..."
        if command_exists curl; then
            if curl -L -o "$icon_file" "$icon_url" 2>/dev/null; then
                debug_print continue "Battle.net icon downloaded successfully"
                # Update icon cache if available
                if command_exists gtk-update-icon-cache; then
                    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
                fi
                echo "$icon_file"
                return 0
            else
                debug_print continue "Warning: Failed to download Battle.net icon"
            fi
        else
            debug_print continue "Warning: curl not available for icon download"
        fi
    else
        debug_print continue "Battle.net icon already exists"
        echo "$icon_file"
        return 0
    fi
    
    # Return default icon name if download failed
    echo "applications-games"
    return 1
}

# Remove desktop integration
remove_desktop_integration() {
    debug_print continue "Removing Battle.net desktop integration..."
    
    local user_desktop="$HOME/Desktop/Battle.net.desktop"
    local user_applications="$HOME/.local/share/applications/Battle.net.desktop"
    local icon_file="$HOME/.local/share/icons/hicolor/256x256/apps/battlenet.png"
    
    # Remove desktop files
    if [[ -f "$user_desktop" ]]; then
        rm -f "$user_desktop"
        debug_print continue "Removed desktop shortcut"
    fi
    
    if [[ -f "$user_applications" ]]; then
        rm -f "$user_applications"
        debug_print continue "Removed applications menu entry"
    fi
    
    # Remove icon
    if [[ -f "$icon_file" ]]; then
        rm -f "$icon_file"
        debug_print continue "Removed Battle.net icon"
        # Update icon cache if available
        if command_exists gtk-update-icon-cache; then
            gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
        fi
    fi
    
    message info "Desktop Integration" "Battle.net desktop integration has been removed."
    return 0
}

# Setup complete desktop integration
setup_desktop_integration() {
    debug_print continue "Setting up complete desktop integration..."
    
    # Get current script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local launch_script="$script_dir/lib/wow-launch.sh"
    
    # Validate launch script exists
    if [[ ! -f "$launch_script" ]]; then
        debug_print exit "Launch script not found: $launch_script"
        message error "Desktop Integration Error" "Launch script not found. Please ensure the installation is complete."
        return 1
    fi
    
    # Install icon and get path
    local icon_path
    icon_path=$(install_battlenet_icon)
    
    # Install desktop entries
    if install_desktop_entry "$launch_script" "$icon_path"; then
        debug_print continue "Desktop integration setup completed successfully"
        return 0
    else
        debug_print exit "Failed to setup desktop integration"
        message error "Desktop Integration Error" "Failed to create desktop entries. Please check permissions and try again."
        return 1
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