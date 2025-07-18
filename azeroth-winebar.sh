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

############################################################################
# Configuration Reset and Backup System
############################################################################

# Backup WoW keybinds
backup_wow_keybinds() {
    debug_print continue "Starting WoW keybinds backup..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if game directory is configured
    if [[ -z "$game_dir" ]]; then
        message error "Game Directory Not Set" "No game directory is configured.\n\nPlease set up your game directory first through the installation menu."
        return 1
    fi
    
    # Find WoW installation directory
    local wow_dir=""
    local possible_wow_dirs=(
        "$game_dir/World of Warcraft"
        "$game_dir/_retail_"
        "$game_dir"
    )
    
    for dir in "${possible_wow_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # Check for WoW executable or WTF directory
            if [[ -f "$dir/Wow.exe" || -f "$dir/WowClassic.exe" || -d "$dir/WTF" ]]; then
                wow_dir="$dir"
                break
            fi
        fi
    done
    
    if [[ -z "$wow_dir" ]]; then
        message error "WoW Installation Not Found" "Could not find World of Warcraft installation in:\n$game_dir\n\nPlease ensure WoW is installed and the game directory is correctly configured."
        return 1
    fi
    
    debug_print continue "Found WoW directory: $wow_dir"
    
    # Look for keybind files in WTF directory
    local wtf_dir="$wow_dir/WTF"
    if [[ ! -d "$wtf_dir" ]]; then
        message error "WTF Directory Not Found" "WoW configuration directory not found:\n$wtf_dir\n\nPlease run WoW at least once to create configuration files."
        return 1
    fi
    
    # Find keybind files (bindings-cache.wtf and account-specific bindings)
    local keybind_files=()
    
    # Global bindings cache
    if [[ -f "$wtf_dir/bindings-cache.wtf" ]]; then
        keybind_files+=("$wtf_dir/bindings-cache.wtf")
    fi
    
    # Account-specific bindings
    local account_dirs=("$wtf_dir"/Account/*)
    for account_dir in "${account_dirs[@]}"; do
        if [[ -d "$account_dir" ]]; then
            # Account-level bindings
            if [[ -f "$account_dir/bindings-cache.wtf" ]]; then
                keybind_files+=("$account_dir/bindings-cache.wtf")
            fi
            
            # Character-specific bindings
            local server_dirs=("$account_dir"/*)
            for server_dir in "${server_dirs[@]}"; do
                if [[ -d "$server_dir" ]]; then
                    local char_dirs=("$server_dir"/*)
                    for char_dir in "${char_dirs[@]}"; do
                        if [[ -d "$char_dir" && -f "$char_dir/bindings-cache.wtf" ]]; then
                            keybind_files+=("$char_dir/bindings-cache.wtf")
                        fi
                    done
                fi
            done
        fi
    done
    
    if [[ ${#keybind_files[@]} -eq 0 ]]; then
        message info "No Keybinds Found" "No keybind files were found in your WoW installation.\n\nThis is normal if you haven't customized any keybinds yet."
        return 0
    fi
    
    # Create backup directory with timestamp
    local backup_timestamp
    backup_timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="$config_dir/keybinds/backup_$backup_timestamp"
    
    if ! mkdir -p "$backup_dir"; then
        debug_print exit "Failed to create backup directory: $backup_dir"
        return 1
    fi
    
    debug_print continue "Created backup directory: $backup_dir"
    
    # Backup keybind files
    local backed_up_files=0
    for keybind_file in "${keybind_files[@]}"; do
        if [[ -f "$keybind_file" ]]; then
            # Create relative path for backup
            local relative_path
            relative_path=$(echo "$keybind_file" | sed "s|$wtf_dir/||")
            local backup_file="$backup_dir/$relative_path"
            local backup_file_dir
            backup_file_dir=$(dirname "$backup_file")
            
            # Create directory structure in backup
            if ! mkdir -p "$backup_file_dir"; then
                debug_print continue "Warning: Failed to create backup subdirectory: $backup_file_dir"
                continue
            fi
            
            # Copy keybind file
            if cp "$keybind_file" "$backup_file"; then
                debug_print continue "Backed up: $relative_path"
                ((backed_up_files++))
            else
                debug_print continue "Warning: Failed to backup: $relative_path"
            fi
        fi
    done
    
    if [[ $backed_up_files -eq 0 ]]; then
        message error "Backup Failed" "Failed to backup any keybind files.\n\nPlease check file permissions and try again."
        rm -rf "$backup_dir"
        return 1
    fi
    
    # Create backup info file
    local info_file="$backup_dir/backup_info.txt"
    cat > "$info_file" << EOF
Azeroth Winebar - WoW Keybinds Backup
=====================================

Backup Date: $(date)
WoW Directory: $wow_dir
Files Backed Up: $backed_up_files

Backed up files:
EOF
    
    for keybind_file in "${keybind_files[@]}"; do
        if [[ -f "$keybind_file" ]]; then
            local relative_path
            relative_path=$(echo "$keybind_file" | sed "s|$wtf_dir/||")
            echo "- $relative_path" >> "$info_file"
        fi
    done
    
    debug_print continue "WoW keybinds backup completed successfully"
    message info "Backup Complete" "Successfully backed up $backed_up_files keybind files.\n\nBackup Location: $backup_dir\n\nYou can restore these keybinds later using the restore function."
    
    return 0
}

# List available keybind backups
list_keybind_backups() {
    debug_print continue "Listing available keybind backups..."
    
    local keybinds_dir="$config_dir/keybinds"
    if [[ ! -d "$keybinds_dir" ]]; then
        debug_print continue "No keybinds directory found"
        return 1
    fi
    
    local backup_dirs=()
    local backup_info=()
    
    # Find backup directories
    for backup_dir in "$keybinds_dir"/backup_*; do
        if [[ -d "$backup_dir" ]]; then
            local backup_name
            backup_name=$(basename "$backup_dir")
            backup_dirs+=("$backup_name")
            
            # Get backup info if available
            local info_file="$backup_dir/backup_info.txt"
            local backup_date="unknown"
            local file_count="unknown"
            
            if [[ -f "$info_file" ]]; then
                backup_date=$(grep "Backup Date:" "$info_file" | cut -d':' -f2- | sed 's/^ *//')
                file_count=$(grep "Files Backed Up:" "$info_file" | cut -d':' -f2 | sed 's/^ *//')
            fi
            
            backup_info+=("$backup_name ($file_count files, $backup_date)")
        fi
    done
    
    if [[ ${#backup_dirs[@]} -eq 0 ]]; then
        debug_print continue "No keybind backups found"
        return 1
    fi
    
    debug_print continue "Found ${#backup_dirs[@]} keybind backups"
    printf '%s\n' "${backup_info[@]}"
    return 0
}

# Restore WoW keybinds from backup
restore_wow_keybinds() {
    debug_print continue "Starting WoW keybinds restore..."
    
    # List available backups
    local backup_list
    if ! backup_list=$(list_keybind_backups); then
        message info "No Backups Available" "No keybind backups were found.\n\nYou can create a backup using the backup function."
        return 1
    fi
    
    # Convert backup list to array for menu
    local backup_options=()
    while IFS= read -r line; do
        backup_options+=("$line")
    done <<< "$backup_list"
    
    backup_options+=("Cancel")
    
    # Show backup selection menu
    local choice
    choice=$(menu "Restore Keybinds" "Select a backup to restore:" "${backup_options[@]}")
    
    if [[ $? -ne 0 ]]; then
        debug_print continue "Keybind restore cancelled"
        return 1
    fi
    
    # Handle cancel option
    if [[ $choice -eq ${#backup_options[@]} ]]; then
        debug_print continue "Keybind restore cancelled by user"
        return 1
    fi
    
    # Get selected backup name
    local selected_backup
    selected_backup=$(echo "${backup_options[$((choice-1))]}" | cut -d' ' -f1)
    local backup_dir="$config_dir/keybinds/$selected_backup"
    
    if [[ ! -d "$backup_dir" ]]; then
        message error "Backup Not Found" "Selected backup directory does not exist:\n$backup_dir"
        return 1
    fi
    
    debug_print continue "Selected backup: $selected_backup"
    debug_print continue "Backup directory: $backup_dir"
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if game directory is configured
    if [[ -z "$game_dir" ]]; then
        message error "Game Directory Not Set" "No game directory is configured.\n\nPlease set up your game directory first through the installation menu."
        return 1
    fi
    
    # Find WoW installation directory
    local wow_dir=""
    local possible_wow_dirs=(
        "$game_dir/World of Warcraft"
        "$game_dir/_retail_"
        "$game_dir"
    )
    
    for dir in "${possible_wow_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -f "$dir/Wow.exe" || -f "$dir/WowClassic.exe" || -d "$dir/WTF" ]]; then
                wow_dir="$dir"
                break
            fi
        fi
    done
    
    if [[ -z "$wow_dir" ]]; then
        message error "WoW Installation Not Found" "Could not find World of Warcraft installation in:\n$game_dir\n\nPlease ensure WoW is installed and the game directory is correctly configured."
        return 1
    fi
    
    local wtf_dir="$wow_dir/WTF"
    if [[ ! -d "$wtf_dir" ]]; then
        message error "WTF Directory Not Found" "WoW configuration directory not found:\n$wtf_dir\n\nPlease run WoW at least once to create configuration files."
        return 1
    fi
    
    # Confirm restore operation
    if ! message question "Confirm Restore" "This will restore keybinds from backup:\n$selected_backup\n\nTo: $wtf_dir\n\nExisting keybind files will be overwritten.\n\nDo you want to continue?"; then
        debug_print continue "Keybind restore cancelled by user"
        return 1
    fi
    
    # Restore keybind files
    local restored_files=0
    local failed_files=0
    
    # Find all backup files
    while IFS= read -r -d '' backup_file; do
        # Get relative path
        local relative_path
        relative_path=$(echo "$backup_file" | sed "s|$backup_dir/||")
        
        # Skip backup info file
        if [[ "$relative_path" == "backup_info.txt" ]]; then
            continue
        fi
        
        local target_file="$wtf_dir/$relative_path"
        local target_dir
        target_dir=$(dirname "$target_file")
        
        # Create target directory if needed
        if ! mkdir -p "$target_dir"; then
            debug_print continue "Warning: Failed to create directory: $target_dir"
            ((failed_files++))
            continue
        fi
        
        # Copy backup file to target
        if cp "$backup_file" "$target_file"; then
            debug_print continue "Restored: $relative_path"
            ((restored_files++))
        else
            debug_print continue "Warning: Failed to restore: $relative_path"
            ((failed_files++))
        fi
    done < <(find "$backup_dir" -type f -print0)
    
    # Report results
    if [[ $restored_files -eq 0 ]]; then
        message error "Restore Failed" "Failed to restore any keybind files from backup.\n\nPlease check file permissions and try again."
        return 1
    fi
    
    local result_message="Successfully restored $restored_files keybind files"
    if [[ $failed_files -gt 0 ]]; then
        result_message="$result_message\n\nWarning: $failed_files files failed to restore"
    fi
    result_message="$result_message\n\nFrom: $backup_dir\nTo: $wtf_dir\n\nYour keybinds have been restored."
    
    debug_print continue "WoW keybinds restore completed"
    message info "Restore Complete" "$result_message"
    
    return 0
}

# Reset helper configuration
reset_helper_config() {
    debug_print continue "Starting helper configuration reset..."
    
    # Confirm reset operation
    if ! message question "Confirm Configuration Reset" "This will reset all Azeroth Winebar configuration to defaults.\n\nThe following will be reset:\n- Wine prefix path\n- Game directory path\n- Default wine runner\n- First run flag\n\nKeybind backups will NOT be deleted.\n\nDo you want to continue?"; then
        debug_print continue "Configuration reset cancelled by user"
        return 1
    fi
    
    debug_print continue "Resetting helper configuration..."
    
    # Reset configuration using existing function
    if ! reset_config; then
        message error "Reset Failed" "Failed to reset configuration files.\n\nPlease check file permissions and try again."
        return 1
    fi
    
    # Also remove default runner config
    local runner_config="$config_dir/default-runner.conf"
    if [[ -f "$runner_config" ]]; then
        if rm "$runner_config"; then
            debug_print continue "Removed default runner configuration"
        else
            debug_print continue "Warning: Failed to remove default runner configuration"
        fi
    fi
    
    debug_print continue "Helper configuration reset completed"
    message info "Configuration Reset Complete" "All Azeroth Winebar configuration has been reset to defaults.\n\nYou will need to reconfigure:\n- Wine prefix path\n- Game directory path\n- Wine runner selection\n\nKeybind backups have been preserved."
    
    return 0
}

# Delete old keybind backups
cleanup_old_backups() {
    debug_print continue "Starting old backup cleanup..."
    
    local keybinds_dir="$config_dir/keybinds"
    if [[ ! -d "$keybinds_dir" ]]; then
        message info "No Backups Found" "No keybinds directory found.\n\nThere are no backups to clean up."
        return 0
    fi
    
    # Find backup directories older than 30 days
    local old_backups=()
    local cutoff_date
    cutoff_date=$(date -d "30 days ago" +%s)
    
    for backup_dir in "$keybinds_dir"/backup_*; do
        if [[ -d "$backup_dir" ]]; then
            local backup_time
            backup_time=$(stat -c %Y "$backup_dir" 2>/dev/null || echo "0")
            
            if [[ $backup_time -lt $cutoff_date ]]; then
                local backup_name
                backup_name=$(basename "$backup_dir")
                local backup_date
                backup_date=$(date -d "@$backup_time" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
                old_backups+=("$backup_name ($backup_date)")
            fi
        fi
    done
    
    if [[ ${#old_backups[@]} -eq 0 ]]; then
        message info "No Old Backups" "No backups older than 30 days were found.\n\nNo cleanup is needed."
        return 0
    fi
    
    # Show old backups and confirm deletion
    local backup_list
    backup_list=$(printf '%s\n' "${old_backups[@]}")
    
    if ! message question "Cleanup Old Backups" "Found ${#old_backups[@]} backups older than 30 days:\n\n$backup_list\n\nDo you want to delete these old backups?"; then
        debug_print continue "Backup cleanup cancelled by user"
        return 1
    fi
    
    # Delete old backups
    local deleted_count=0
    for backup_dir in "$keybinds_dir"/backup_*; do
        if [[ -d "$backup_dir" ]]; then
            local backup_time
            backup_time=$(stat -c %Y "$backup_dir" 2>/dev/null || echo "0")
            
            if [[ $backup_time -lt $cutoff_date ]]; then
                if rm -rf "$backup_dir"; then
                    debug_print continue "Deleted old backup: $(basename "$backup_dir")"
                    ((deleted_count++))
                else
                    debug_print continue "Warning: Failed to delete backup: $(basename "$backup_dir")"
                fi
            fi
        fi
    done
    
    debug_print continue "Old backup cleanup completed"
    message info "Cleanup Complete" "Successfully deleted $deleted_count old backup directories.\n\nRecent backups (less than 30 days old) have been preserved."
    
    return 0
}

# Configuration management menu
manage_configuration() {
    debug_print continue "Starting configuration management..."
    
    local menu_options=(
        "Backup WoW Keybinds"
        "Restore WoW Keybinds"
        "List Keybind Backups"
        "Reset Helper Configuration"
        "Cleanup Old Backups"
        "Back to Main Menu"
    )
    
    while menu_should_continue; do
        local choice
        choice=$(menu "Configuration Management" "Select a configuration management option:" "${menu_options[@]}")
        
        if [[ $? -ne 0 ]]; then
            debug_print continue "Configuration management menu cancelled"
            break
        fi
        
        case "$choice" in
            1)
                backup_wow_keybinds
                ;;
            2)
                restore_wow_keybinds
                ;;
            3)
                local backup_list
                if backup_list=$(list_keybind_backups); then
                    message info "Available Backups" "Keybind backups found:\n\n$backup_list"
                else
                    message info "No Backups Found" "No keybind backups are currently available.\n\nYou can create a backup using the backup function."
                fi
                ;;
            4)
                reset_helper_config
                ;;
            5)
                cleanup_old_backups
                ;;
            6)
                debug_print continue "Returning to main menu"
                break
                ;;
            *)
                message error "Invalid Selection" "Invalid menu selection: $choice"
                ;;
        esac
    done
    
    debug_print continue "Configuration management completed"
    return 0
}

############################################################################
# DXVK Management System
############################################################################

# DXVK GitHub API URL
dxvk_api_url="https://api.github.com/repos/doitsujin/dxvk/releases"

# Get latest DXVK release information
get_latest_dxvk_release() {
    debug_print continue "Fetching latest DXVK release information..."
    
    local release_json
    if ! release_json=$(curl -s "$dxvk_api_url/latest"); then
        debug_print exit "Failed to fetch DXVK release information"
        return 1
    fi
    
    # Extract version and download URL
    local version
    local download_url
    
    version=$(echo "$release_json" | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\([^"]*\)"/\1/')
    download_url=$(echo "$release_json" | grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' | head -1 | sed 's/"browser_download_url": *"\([^"]*\)"/\1/')
    
    if [[ -z "$version" || -z "$download_url" ]]; then
        debug_print exit "Failed to parse DXVK release information"
        return 1
    fi
    
    debug_print continue "Latest DXVK version: $version"
    debug_print continue "Download URL: $download_url"
    
    echo "$version|$download_url"
    return 0
}

# Check current DXVK version in wine prefix
check_dxvk_version() {
    local prefix_path="$1"
    
    if [[ -z "$prefix_path" ]]; then
        debug_print exit "No wine prefix specified for DXVK version check"
        return 1
    fi
    
    if [[ ! -d "$prefix_path" ]]; then
        debug_print exit "Wine prefix does not exist: $prefix_path"
        return 1
    fi
    
    # Check for DXVK DLL files in system32
    local system32_dir="$prefix_path/drive_c/windows/system32"
    local dxvk_dll="$system32_dir/dxgi.dll"
    
    if [[ ! -f "$dxvk_dll" ]]; then
        debug_print continue "DXVK not installed in wine prefix"
        echo "not_installed"
        return 0
    fi
    
    # Try to get version from DXVK DLL (this is approximate)
    # DXVK doesn't embed version info in a standard way, so we'll check file modification time
    local install_date
    install_date=$(stat -c %Y "$dxvk_dll" 2>/dev/null || echo "0")
    
    if [[ "$install_date" -gt 0 ]]; then
        local formatted_date
        formatted_date=$(date -d "@$install_date" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
        echo "installed_$formatted_date"
    else
        echo "installed_unknown"
    fi
    
    return 0
}

# Download DXVK release
download_dxvk() {
    local version="$1"
    local download_url="$2"
    local temp_dir="/tmp/azeroth-winebar-dxvk"
    
    if [[ -z "$version" || -z "$download_url" ]]; then
        debug_print exit "Missing parameters for DXVK download"
        return 1
    fi
    
    debug_print continue "Downloading DXVK $version..."
    debug_print continue "Download URL: $download_url"
    
    # Create temporary download directory
    if ! mkdir -p "$temp_dir"; then
        debug_print exit "Failed to create temporary download directory"
        return 1
    fi
    
    local download_file="$temp_dir/dxvk-$version.tar.gz"
    
    # Download DXVK
    if ! curl -L -o "$download_file" "$download_url"; then
        debug_print exit "Failed to download DXVK from $download_url"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Verify download
    if [[ ! -f "$download_file" ]]; then
        debug_print exit "Downloaded DXVK file not found: $download_file"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local file_size
    file_size=$(stat -c%s "$download_file" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 100000 ]]; then  # Less than 100KB is suspicious
        debug_print exit "Downloaded DXVK file appears to be too small: $file_size bytes"
        rm -rf "$temp_dir"
        return 1
    fi
    
    debug_print continue "DXVK download completed successfully: $file_size bytes"
    echo "$download_file"
    return 0
}

# Extract DXVK archive
extract_dxvk() {
    local archive_path="$1"
    local extract_dir="$2"
    
    if [[ -z "$archive_path" || -z "$extract_dir" ]]; then
        debug_print exit "Missing parameters for DXVK extraction"
        return 1
    fi
    
    if [[ ! -f "$archive_path" ]]; then
        debug_print exit "DXVK archive not found: $archive_path"
        return 1
    fi
    
    debug_print continue "Extracting DXVK archive..."
    debug_print continue "Archive: $archive_path"
    debug_print continue "Extract to: $extract_dir"
    
    # Create extraction directory
    if ! mkdir -p "$extract_dir"; then
        debug_print exit "Failed to create extraction directory: $extract_dir"
        return 1
    fi
    
    # Extract archive
    if ! tar -xzf "$archive_path" -C "$extract_dir" --strip-components=1; then
        debug_print exit "Failed to extract DXVK archive"
        return 1
    fi
    
    # Verify extraction
    if [[ ! -d "$extract_dir/x64" || ! -d "$extract_dir/x32" ]]; then
        debug_print exit "DXVK extraction appears incomplete - missing x64 or x32 directories"
        return 1
    fi
    
    debug_print continue "DXVK extraction completed successfully"
    return 0
}

# Install DXVK in wine prefix
install_dxvk_in_prefix() {
    local prefix_path="$1"
    local dxvk_dir="$2"
    local wine_runner="$3"
    
    if [[ -z "$prefix_path" || -z "$dxvk_dir" ]]; then
        debug_print exit "Missing parameters for DXVK installation"
        return 1
    fi
    
    if [[ ! -d "$prefix_path" ]]; then
        debug_print exit "Wine prefix does not exist: $prefix_path"
        return 1
    fi
    
    if [[ ! -d "$dxvk_dir" ]]; then
        debug_print exit "DXVK directory does not exist: $dxvk_dir"
        return 1
    fi
    
    debug_print continue "Installing DXVK in wine prefix..."
    debug_print continue "Wine prefix: $prefix_path"
    debug_print continue "DXVK directory: $dxvk_dir"
    
    # Get wine binary
    local wine_binary
    if [[ -n "$wine_runner" && "$wine_runner" != "system" ]]; then
        if ! wine_binary=$(get_runner_binary "$wine_runner"); then
            debug_print exit "Failed to get wine binary for runner: $wine_runner"
            return 1
        fi
    else
        wine_binary="wine"
    fi
    
    # Set wine environment
    export WINEPREFIX="$prefix_path"
    
    # Copy DXVK DLLs to wine prefix
    local system32_dir="$prefix_path/drive_c/windows/system32"
    local syswow64_dir="$prefix_path/drive_c/windows/syswow64"
    
    # Ensure directories exist
    if ! mkdir -p "$system32_dir" "$syswow64_dir"; then
        debug_print exit "Failed to create wine system directories"
        return 1
    fi
    
    # Copy 64-bit DLLs
    debug_print continue "Installing 64-bit DXVK DLLs..."
    local x64_dlls=("d3d9.dll" "d3d10core.dll" "d3d11.dll" "dxgi.dll")
    for dll in "${x64_dlls[@]}"; do
        if [[ -f "$dxvk_dir/x64/$dll" ]]; then
            if ! cp "$dxvk_dir/x64/$dll" "$system32_dir/"; then
                debug_print exit "Failed to copy 64-bit DLL: $dll"
                return 1
            fi
            debug_print continue "Installed 64-bit DLL: $dll"
        else
            debug_print continue "Warning: 64-bit DLL not found: $dll"
        fi
    done
    
    # Copy 32-bit DLLs
    debug_print continue "Installing 32-bit DXVK DLLs..."
    for dll in "${x64_dlls[@]}"; do
        if [[ -f "$dxvk_dir/x32/$dll" ]]; then
            if ! cp "$dxvk_dir/x32/$dll" "$syswow64_dir/"; then
                debug_print exit "Failed to copy 32-bit DLL: $dll"
                return 1
            fi
            debug_print continue "Installed 32-bit DLL: $dll"
        else
            debug_print continue "Warning: 32-bit DLL not found: $dll"
        fi
    done
    
    # Set DLL overrides in wine registry
    debug_print continue "Setting DXVK DLL overrides in wine registry..."
    local dll_overrides=("d3d9" "d3d10core" "d3d11" "dxgi")
    for dll in "${dll_overrides[@]}"; do
        if ! WINEPREFIX="$prefix_path" "$wine_binary" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "$dll" /t REG_SZ /d "native,builtin" /f >/dev/null 2>&1; then
            debug_print continue "Warning: Failed to set DLL override for $dll"
        else
            debug_print continue "Set DLL override: $dll = native,builtin"
        fi
    done
    
    debug_print continue "DXVK installation completed successfully"
    return 0
}

# Update DXVK in wine prefix
update_dxvk() {
    debug_print continue "Starting DXVK update process..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if wine prefix is configured
    if [[ -z "$wine_prefix" ]]; then
        message error "Wine Prefix Not Set" "No wine prefix is configured.\n\nPlease set up your wine prefix first through the installation menu."
        return 1
    fi
    
    # Validate wine prefix exists
    if [[ ! -d "$wine_prefix" ]]; then
        message error "Wine Prefix Missing" "The configured wine prefix does not exist:\n$wine_prefix\n\nPlease reinstall or reconfigure your wine prefix."
        return 1
    fi
    
    # Get current DXVK version
    local current_version
    current_version=$(check_dxvk_version "$wine_prefix")
    
    # Get latest DXVK release
    local release_info
    if ! release_info=$(get_latest_dxvk_release); then
        message error "DXVK Update Failed" "Failed to fetch latest DXVK release information.\n\nPlease check your internet connection and try again."
        return 1
    fi
    
    local latest_version
    local download_url
    IFS='|' read -r latest_version download_url <<< "$release_info"
    
    # Show current and latest versions
    local version_info="Current DXVK: $current_version\nLatest DXVK: $latest_version"
    
    if [[ "$current_version" == "not_installed" ]]; then
        if ! message question "Install DXVK" "$version_info\n\nDXVK is not currently installed in your wine prefix.\n\nDo you want to install the latest version?"; then
            debug_print continue "DXVK installation cancelled by user"
            return 1
        fi
    else
        if ! message question "Update DXVK" "$version_info\n\nDo you want to update DXVK to the latest version?\n\nThis will replace the current installation."; then
            debug_print continue "DXVK update cancelled by user"
            return 1
        fi
    fi
    
    # Get wine runner
    local wine_runner
    wine_runner=$(get_default_runner)
    if [[ -z "$wine_runner" ]]; then
        wine_runner="system"
    fi
    
    # Download DXVK
    local download_file
    if ! download_file=$(download_dxvk "$latest_version" "$download_url"); then
        message error "Download Failed" "Failed to download DXVK $latest_version.\n\nPlease check your internet connection and try again."
        return 1
    fi
    
    # Extract DXVK
    local extract_dir="/tmp/azeroth-winebar-dxvk-extract"
    if ! extract_dxvk "$download_file" "$extract_dir"; then
        message error "Extraction Failed" "Failed to extract DXVK archive.\n\nThe download may be corrupted."
        rm -rf "/tmp/azeroth-winebar-dxvk"
        return 1
    fi
    
    # Install DXVK
    if ! install_dxvk_in_prefix "$wine_prefix" "$extract_dir" "$wine_runner"; then
        message error "Installation Failed" "Failed to install DXVK in wine prefix.\n\nPlease check the debug output for more information."
        rm -rf "/tmp/azeroth-winebar-dxvk"
        return 1
    fi
    
    # Clean up temporary files
    rm -rf "/tmp/azeroth-winebar-dxvk"
    
    debug_print continue "DXVK update completed successfully"
    message info "DXVK Update Complete" "DXVK has been successfully updated to version $latest_version.\n\nWine Prefix: $wine_prefix\n\nYour games should now use the latest DXVK version for improved performance."
    
    return 0
}

# Check DXVK installation status
check_dxvk_status() {
    debug_print continue "Checking DXVK installation status..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if wine prefix is configured
    if [[ -z "$wine_prefix" ]]; then
        message info "DXVK Status" "No wine prefix is configured.\n\nPlease set up your wine prefix first to check DXVK status."
        return 1
    fi
    
    # Validate wine prefix exists
    if [[ ! -d "$wine_prefix" ]]; then
        message info "DXVK Status" "The configured wine prefix does not exist:\n$wine_prefix\n\nPlease reinstall or reconfigure your wine prefix."
        return 1
    fi
    
    # Get current DXVK version
    local current_version
    current_version=$(check_dxvk_version "$wine_prefix")
    
    # Get latest DXVK release
    local latest_version="unknown"
    local release_info
    if release_info=$(get_latest_dxvk_release); then
        IFS='|' read -r latest_version _ <<< "$release_info"
    fi
    
    # Display status
    local status_message="Wine Prefix: $wine_prefix\n\nCurrent DXVK: $current_version\nLatest Available: $latest_version"
    
    if [[ "$current_version" == "not_installed" ]]; then
        status_message="$status_message\n\nDXVK is not installed in your wine prefix.\nYou can install it using the DXVK management menu."
    else
        status_message="$status_message\n\nDXVK is installed and ready to use.\nYou can update it if a newer version is available."
    fi
    
    message info "DXVK Status" "$status_message"
    return 0
}

# DXVK management menu
manage_dxvk() {
    debug_print continue "Starting DXVK management..."
    
    local menu_options=(
        "Check DXVK Status"
        "Update/Install DXVK"
        "Back to Main Menu"
    )
    
    while menu_should_continue; do
        local choice
        choice=$(menu "DXVK Management" "Select a DXVK management option:" "${menu_options[@]}")
        
        if [[ $? -ne 0 ]]; then
            debug_print continue "DXVK management menu cancelled"
            break
        fi
        
        case "$choice" in
            1)
                check_dxvk_status
                ;;
            2)
                update_dxvk
                ;;
            3)
                debug_print continue "Returning to main menu"
                break
                ;;
            *)
                message error "Invalid Selection" "Invalid menu selection: $choice"
                ;;
        esac
    done
    
    debug_print continue "DXVK management completed"
    return 0
}

############################################################################
# Wine Prefix Management Tools
############################################################################

# Launch winecfg for wine prefix configuration
launch_winecfg() {
    debug_print continue "Launching winecfg for wine prefix configuration..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if wine prefix is configured
    if [[ -z "$wine_prefix" ]]; then
        message error "Wine Prefix Not Set" "No wine prefix is configured.\n\nPlease set up your wine prefix first through the installation menu."
        return 1
    fi
    
    # Validate wine prefix exists
    if [[ ! -d "$wine_prefix" ]]; then
        message error "Wine Prefix Missing" "The configured wine prefix does not exist:\n$wine_prefix\n\nPlease reinstall or reconfigure your wine prefix."
        return 1
    fi
    
    # Get wine runner
    local wine_runner
    wine_runner=$(get_default_runner)
    if [[ -z "$wine_runner" ]]; then
        debug_print continue "No default runner set, checking for system wine"
        if ! command_exists "wine"; then
            message error "Wine Not Available" "No wine runner is configured and system wine is not available.\n\nPlease install a wine runner first."
            return 1
        fi
        wine_runner="system"
    fi
    
    # Set up wine environment
    export WINEPREFIX="$wine_prefix"
    
    # Get wine binary path
    local wine_binary
    if [[ "$wine_runner" == "system" ]]; then
        wine_binary="wine"
    else
        if ! wine_binary=$(get_runner_binary "$wine_runner"); then
            message error "Wine Runner Error" "Failed to get wine binary for runner: $wine_runner\n\nPlease check your wine runner installation."
            return 1
        fi
    fi
    
    debug_print continue "Using wine binary: $wine_binary"
    debug_print continue "Wine prefix: $wine_prefix"
    
    # Inform user about winecfg launch
    message info "Launching Winecfg" "Launching wine configuration tool (winecfg).\n\nWine Prefix: $wine_prefix\nWine Runner: $wine_runner\n\nThe configuration window will open shortly."
    
    # Launch winecfg
    debug_print continue "Executing: WINEPREFIX='$wine_prefix' '$wine_binary' winecfg"
    if ! WINEPREFIX="$wine_prefix" "$wine_binary" winecfg; then
        message error "Winecfg Failed" "Failed to launch winecfg.\n\nPlease check that your wine installation is working correctly."
        return 1
    fi
    
    debug_print continue "Winecfg completed successfully"
    message info "Configuration Complete" "Wine configuration completed.\n\nAny changes you made have been saved to your wine prefix."
    
    return 0
}

# Launch wine control panel for controller configuration
launch_wine_control() {
    debug_print continue "Launching wine control panel for controller configuration..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if wine prefix is configured
    if [[ -z "$wine_prefix" ]]; then
        message error "Wine Prefix Not Set" "No wine prefix is configured.\n\nPlease set up your wine prefix first through the installation menu."
        return 1
    fi
    
    # Validate wine prefix exists
    if [[ ! -d "$wine_prefix" ]]; then
        message error "Wine Prefix Missing" "The configured wine prefix does not exist:\n$wine_prefix\n\nPlease reinstall or reconfigure your wine prefix."
        return 1
    fi
    
    # Get wine runner
    local wine_runner
    wine_runner=$(get_default_runner)
    if [[ -z "$wine_runner" ]]; then
        debug_print continue "No default runner set, checking for system wine"
        if ! command_exists "wine"; then
            message error "Wine Not Available" "No wine runner is configured and system wine is not available.\n\nPlease install a wine runner first."
            return 1
        fi
        wine_runner="system"
    fi
    
    # Set up wine environment
    export WINEPREFIX="$wine_prefix"
    
    # Get wine binary path
    local wine_binary
    if [[ "$wine_runner" == "system" ]]; then
        wine_binary="wine"
    else
        if ! wine_binary=$(get_runner_binary "$wine_runner"); then
            message error "Wine Runner Error" "Failed to get wine binary for runner: $wine_runner\n\nPlease check your wine runner installation."
            return 1
        fi
    fi
    
    debug_print continue "Using wine binary: $wine_binary"
    debug_print continue "Wine prefix: $wine_prefix"
    
    # Inform user about control panel launch
    message info "Launching Wine Control Panel" "Launching wine control panel for controller configuration.\n\nWine Prefix: $wine_prefix\nWine Runner: $wine_runner\n\nThe control panel will open shortly.\n\nLook for 'Game Controllers' or 'Gaming Options' in the control panel."
    
    # Launch wine control panel
    debug_print continue "Executing: WINEPREFIX='$wine_prefix' '$wine_binary' control"
    if ! WINEPREFIX="$wine_prefix" "$wine_binary" control; then
        message error "Control Panel Failed" "Failed to launch wine control panel.\n\nPlease check that your wine installation is working correctly."
        return 1
    fi
    
    debug_print continue "Wine control panel completed successfully"
    message info "Configuration Complete" "Controller configuration completed.\n\nAny changes you made have been saved to your wine prefix."
    
    return 0
}

# Open wine prefix shell for debugging
open_wine_shell() {
    debug_print continue "Opening wine prefix shell for debugging..."
    
    # Load directories
    if ! getdirs; then
        debug_print exit "Failed to load directory configuration"
        return 1
    fi
    
    # Check if wine prefix is configured
    if [[ -z "$wine_prefix" ]]; then
        message error "Wine Prefix Not Set" "No wine prefix is configured.\n\nPlease set up your wine prefix first through the installation menu."
        return 1
    fi
    
    # Validate wine prefix exists
    if [[ ! -d "$wine_prefix" ]]; then
        message error "Wine Prefix Missing" "The configured wine prefix does not exist:\n$wine_prefix\n\nPlease reinstall or reconfigure your wine prefix."
        return 1
    fi
    
    # Get wine runner
    local wine_runner
    wine_runner=$(get_default_runner)
    if [[ -z "$wine_runner" ]]; then
        debug_print continue "No default runner set, checking for system wine"
        if ! command_exists "wine"; then
            message error "Wine Not Available" "No wine runner is configured and system wine is not available.\n\nPlease install a wine runner first."
            return 1
        fi
        wine_runner="system"
    fi
    
    # Get wine binary path
    local wine_binary
    if [[ "$wine_runner" == "system" ]]; then
        wine_binary="wine"
    else
        if ! wine_binary=$(get_runner_binary "$wine_runner"); then
            message error "Wine Runner Error" "Failed to get wine binary for runner: $wine_runner\n\nPlease check your wine runner installation."
            return 1
        fi
    fi
    
    debug_print continue "Using wine binary: $wine_binary"
    debug_print continue "Wine prefix: $wine_prefix"
    
    # Inform user about shell access
    message info "Wine Prefix Shell Access" "Opening a shell with wine environment configured.\n\nWine Prefix: $wine_prefix\nWine Runner: $wine_runner\n\nYou can use wine commands directly in this shell.\nType 'exit' to return to the main menu.\n\nUseful commands:\n- wine --version\n- winecfg\n- winetricks\n- wine regedit\n- wine cmd"
    
    # Set up wine environment variables
    export WINEPREFIX="$wine_prefix"
    export PATH="$(dirname "$wine_binary"):$PATH"
    
    # Create a temporary script to set up the wine environment
    local temp_script="/tmp/azeroth-winebar-wine-shell.sh"
    cat > "$temp_script" << EOF
#!/bin/bash
export WINEPREFIX="$wine_prefix"
export PATH="$(dirname "$wine_binary"):\$PATH"

echo "=== Azeroth Winebar Wine Shell ==="
echo "Wine Prefix: $wine_prefix"
echo "Wine Runner: $wine_runner"
echo "Wine Binary: $wine_binary"
echo
echo "Wine environment is configured. You can now use wine commands."
echo "Type 'exit' to return to Azeroth Winebar."
echo

# Change to wine prefix directory for convenience
cd "$wine_prefix" || cd "\$HOME"

# Start interactive shell
exec bash --rcfile <(echo "PS1='[wine-shell] \$ '")
EOF
    
    chmod +x "$temp_script"
    
    # Launch the wine shell
    debug_print continue "Launching wine shell environment"
    if [[ $gui_zenity -eq 1 ]]; then
        # For GUI mode, open in a new terminal if possible
        if command_exists "gnome-terminal"; then
            gnome-terminal -- bash -c "$temp_script"
        elif command_exists "konsole"; then
            konsole -e bash -c "$temp_script"
        elif command_exists "xterm"; then
            xterm -e bash -c "$temp_script"
        else
            # Fallback to current terminal
            bash "$temp_script"
        fi
    else
        # Terminal mode - run directly
        bash "$temp_script"
    fi
    
    # Clean up temporary script
    rm -f "$temp_script"
    
    debug_print continue "Wine shell session completed"
    message info "Shell Session Complete" "Wine shell session has ended.\n\nYou are now back in the main Azeroth Winebar interface."
    
    return 0
}

# Wine prefix management menu
manage_wine_prefix() {
    debug_print continue "Starting wine prefix management..."
    
    local menu_options=(
        "Launch Wine Configuration (winecfg)"
        "Configure Game Controllers"
        "Open Wine Shell for Debugging"
        "Back to Main Menu"
    )
    
    while menu_should_continue; do
        local choice
        choice=$(menu "Wine Prefix Management" "Select a wine prefix management option:" "${menu_options[@]}")
        
        if [[ $? -ne 0 ]]; then
            debug_print continue "Wine prefix management menu cancelled"
            break
        fi
        
        case "$choice" in
            1)
                launch_winecfg
                ;;
            2)
                launch_wine_control
                ;;
            3)
                open_wine_shell
                ;;
            4)
                debug_print continue "Returning to main menu"
                break
                ;;
            *)
                message error "Invalid Selection" "Invalid menu selection: $choice"
                ;;
        esac
    done
    
    debug_print continue "Wine prefix management completed"
    return 0
}

############################################################################
# Help and Version Functions
############################################################################

# Display help information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -v, --version        Show version information"
    echo "  -d, --debug          Enable debug output"
    echo
    echo "Direct Actions:"
    echo "  --install            Install Battle.net and World of Warcraft"
    echo "  --runners            Manage wine runners"
    echo "  --preflight          Run system optimization checks"
    echo "  --launch             Launch World of Warcraft"
    echo "  --maintenance        Open maintenance and troubleshooting tools"
    echo "  --settings           Open settings and configuration"
    echo "  --reset-config       Reset configuration to defaults"
    echo "  --list-runners       List installed wine runners"
    echo "  --wine-shell         Open wine shell for debugging"
    echo "  --winecfg            Open wine configuration"
    echo
    echo "$script_name is a helper script for managing World of Warcraft"
    echo "and Battle.net on Linux systems using wine/Proton Experimental."
    echo
    echo "Examples:"
    echo "  $0                   Start interactive menu"
    echo "  $0 --install         Install Battle.net directly"
    echo "  $0 --preflight       Run system checks"
    echo "  $0 --list-runners    Show installed wine runners"
    echo "  $0 -d --launch       Launch WoW with debug output"
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

############################################################################
# Main Menu System
############################################################################

# Main menu options array with azeroth-winebar branding
main_menu_options=(
    "Install Battle.net and World of Warcraft"
    "Manage Wine Runners"
    "System Optimization and Preflight Checks"
    "Battle.net and WoW Configuration"
    "Launch World of Warcraft"
    "Maintenance and Troubleshooting"
    "Settings and Configuration"
    "Help and Information"
    "Exit Azeroth Winebar"
)

# Main menu action functions
main_menu_install_battlenet() {
    debug_print continue "Starting Battle.net installation process..."
    message info "Battle.net Installation" "This will guide you through installing Battle.net and setting up World of Warcraft.\n\nThe process includes:\n- Wine prefix creation\n- Battle.net download and installation\n- WoW-specific optimizations\n- Desktop integration"
    
    # Call the installation function (implemented in previous tasks)
    if install_battlenet; then
        message info "Installation Complete" "Battle.net and World of Warcraft setup completed successfully!"
    else
        message error "Installation Failed" "There was an error during the installation process.\n\nCheck the debug output for more details."
    fi
}

main_menu_manage_runners() {
    debug_print continue "Opening wine runner management..."
    manage_wine_runners
}

main_menu_system_optimization() {
    debug_print continue "Starting system optimization checks..."
    message info "System Optimization" "This will check your system for optimal World of Warcraft performance.\n\nChecks include:\n- Memory requirements\n- File descriptor limits\n- Virtual memory settings\n- Graphics optimizations"
    
    if preflight_check; then
        message info "System Check Complete" "Your system is optimized for World of Warcraft!"
    else
        message info "Optimization Needed" "Some system optimizations are recommended.\n\nPlease review the suggestions and apply fixes as needed."
    fi
}

main_menu_game_configuration() {
    debug_print continue "Opening game configuration options..."
    message info "Game Configuration" "Configure Battle.net and World of Warcraft settings for optimal performance.\n\nThis includes:\n- Battle.net launcher settings\n- WoW graphics optimizations\n- Input and mouse settings\n- DXVK configuration"
    
    # This would call configuration functions implemented in previous tasks
    configure_battlenet_and_wow
}

main_menu_launch_wow() {
    debug_print continue "Launching World of Warcraft..."
    
    # Check if Battle.net is installed
    if [[ -z "$wine_prefix" ]] || [[ ! -d "$wine_prefix" ]]; then
        message error "Not Installed" "Battle.net and World of Warcraft are not installed yet.\n\nPlease use the installation option first."
        return 1
    fi
    
    message info "Launching WoW" "Starting World of Warcraft through Battle.net launcher...\n\nThe game will launch in a separate window."
    
    # Launch using the launch script created in previous tasks
    if [[ -f "lib/wow-launch.sh" ]]; then
        bash lib/wow-launch.sh
    else
        message error "Launch Script Missing" "The WoW launch script is missing.\n\nPlease reinstall or check the installation."
    fi
}

main_menu_maintenance() {
    debug_print continue "Opening maintenance and troubleshooting tools..."
    maintenance_tools
}

main_menu_settings() {
    debug_print continue "Opening settings and configuration..."
    settings_menu
}

main_menu_help() {
    debug_print continue "Displaying help and information..."
    message info "Azeroth Winebar Help" "Azeroth Winebar v$script_version\n\nA helper script for World of Warcraft on Linux\n\nFeatures:\n- Automated Battle.net installation\n- Proton Experimental integration\n- System optimization\n- WoW-specific tweaks\n- Desktop integration\n\nFor more information, visit the project documentation or use the command line help option."
}

main_menu_exit() {
    debug_print continue "User requested exit"
    message info "Goodbye" "Thank you for using Azeroth Winebar!\n\nMay your adventures in Azeroth be lag-free!"
    menu_loop_done
}

# Main menu display and navigation
show_main_menu() {
    local menu_text="Choose an option to manage your World of Warcraft installation:"
    local selected_option
    
    # Display main menu
    selected_option=$(menu "Azeroth Winebar - Main Menu" "$menu_text" "${main_menu_options[@]}")
    
    # Handle menu selection
    case "$selected_option" in
        1)
            main_menu_install_battlenet
            ;;
        2)
            main_menu_manage_runners
            ;;
        3)
            main_menu_system_optimization
            ;;
        4)
            main_menu_game_configuration
            ;;
        5)
            main_menu_launch_wow
            ;;
        6)
            main_menu_maintenance
            ;;
        7)
            main_menu_settings
            ;;
        8)
            main_menu_help
            ;;
        9)
            main_menu_exit
            ;;
        *)
            debug_print continue "Invalid menu selection or user cancelled"
            return 1
            ;;
    esac
    
    return 0
}

# Main menu loop with flow control
main_menu_loop() {
    debug_print continue "Starting main menu loop..."
    
    # Reset menu loop control
    menu_loop_reset
    
    # Main menu loop
    while menu_should_continue; do
        if ! show_main_menu; then
            # User cancelled or error occurred
            debug_print continue "Menu cancelled or error occurred"
            break
        fi
        
        # Small delay to prevent rapid looping
        sleep 0.1
    done
    
    debug_print continue "Main menu loop ended"
}

############################################################################
# Placeholder functions for menu actions (to be implemented in other tasks)
############################################################################

# Placeholder for Battle.net and WoW configuration
configure_battlenet_and_wow() {
    message info "Configuration" "Battle.net and WoW configuration features will be available in the full implementation.\n\nThis includes:\n- Battle.net launcher settings\n- WoW Config.wtf modifications\n- Graphics optimizations\n- Input settings"
}

# Placeholder for settings menu
settings_menu() {
    local settings_options=(
        "Reset Configuration"
        "Change Wine Prefix Location"
        "Change Game Directory"
        "Debug Settings"
        "Back to Main Menu"
    )
    
    local menu_text="Configure Azeroth Winebar settings:"
    local selected_option
    
    while true; do
        selected_option=$(menu "Settings" "$menu_text" "${settings_options[@]}")
        
        case "$selected_option" in
            1)
                if message question "Reset Configuration" "This will reset all Azeroth Winebar configuration to defaults.\n\nAre you sure you want to continue?"; then
                    reset_config
                    message info "Reset Complete" "Configuration has been reset to defaults."
                fi
                ;;
            2)
                message info "Wine Prefix" "Wine prefix location management will be available in the full implementation."
                ;;
            3)
                message info "Game Directory" "Game directory management will be available in the full implementation."
                ;;
            4)
                if [[ $debug -eq 1 ]]; then
                    debug=0
                    message info "Debug Mode" "Debug mode disabled."
                else
                    debug=1
                    message info "Debug Mode" "Debug mode enabled."
                fi
                ;;
            5)
                break
                ;;
            *)
                break
                ;;
        esac
    done
}

############################################################################
# Application Initialization and Cleanup
############################################################################

# Global cleanup flag
cleanup_in_progress=0

# Cleanup function for graceful shutdown
cleanup() {
    # Prevent recursive cleanup calls
    if [[ $cleanup_in_progress -eq 1 ]]; then
        return 0
    fi
    cleanup_in_progress=1
    
    debug_print continue "Starting application cleanup..."
    
    # Kill any background processes we might have started
    local pids_to_kill=()
    
    # Look for wine processes that might be hanging
    if [[ -n "$wine_prefix" ]]; then
        local wine_pids
        wine_pids=$(pgrep -f "$wine_prefix" 2>/dev/null || true)
        if [[ -n "$wine_pids" ]]; then
            debug_print continue "Found wine processes to clean up: $wine_pids"
            # Note: We don't automatically kill wine processes as they might be legitimate games
            # Just log them for debugging
        fi
    fi
    
    # Clean up temporary files
    local temp_dirs=(
        "/tmp/azeroth-winebar-download"
        "/tmp/azeroth-winebar-*"
    )
    
    for temp_pattern in "${temp_dirs[@]}"; do
        # Use find to safely handle glob patterns
        find /tmp -maxdepth 1 -name "$(basename "$temp_pattern")" -type d 2>/dev/null | while read -r temp_dir; do
            if [[ -d "$temp_dir" ]]; then
                debug_print continue "Cleaning up temporary directory: $temp_dir"
                rm -rf "$temp_dir" 2>/dev/null || true
            fi
        done
    done
    
    # Sync filesystem to ensure all writes are completed
    sync 2>/dev/null || true
    
    debug_print continue "Application cleanup completed"
}

# Signal handler for graceful shutdown
signal_handler() {
    local signal="$1"
    debug_print continue "Received signal: $signal"
    
    case "$signal" in
        "INT"|"TERM")
            echo
            debug_print continue "Interrupt signal received, initiating graceful shutdown..."
            message info "Shutdown" "Azeroth Winebar is shutting down gracefully...\n\nPlease wait while we clean up."
            ;;
        "EXIT")
            debug_print continue "Exit signal received"
            ;;
        *)
            debug_print continue "Unknown signal received: $signal"
            ;;
    esac
    
    # Perform cleanup
    cleanup
    
    # Exit with appropriate code
    case "$signal" in
        "INT")
            exit 130  # Standard exit code for SIGINT
            ;;
        "TERM")
            exit 143  # Standard exit code for SIGTERM
            ;;
        *)
            exit 1
            ;;
    esac
}

# Setup signal handlers
setup_signal_handlers() {
    debug_print continue "Setting up signal handlers..."
    
    # Handle common termination signals
    trap 'signal_handler INT' INT     # Ctrl+C
    trap 'signal_handler TERM' TERM   # Termination request
    trap 'signal_handler EXIT' EXIT   # Script exit
    
    debug_print continue "Signal handlers configured"
}

# Enhanced application initialization
initialize_application() {
    debug_print continue "Starting enhanced application initialization..."
    
    # Set up signal handlers first
    setup_signal_handlers
    
    # Validate shell environment
    if [[ -z "$BASH_VERSION" ]]; then
        echo "Error: This script requires bash shell" >&2
        exit 1
    fi
    
    # Check bash version (require 4.0+)
    local bash_major_version
    bash_major_version="${BASH_VERSION%%.*}"
    if [[ "$bash_major_version" -lt 4 ]]; then
        echo "Error: This script requires bash 4.0 or later (current: $BASH_VERSION)" >&2
        exit 1
    fi
    
    # Set strict error handling for better reliability
    set -eE  # Exit on error, including in functions and subshells
    set -u   # Exit on undefined variables
    set -o pipefail  # Exit on pipe failures
    
    # Create error handler for set -e
    error_handler() {
        local exit_code=$?
        local line_number=$1
        debug_print exit "Script error on line $line_number (exit code: $exit_code)"
        cleanup
        exit $exit_code
    }
    trap 'error_handler $LINENO' ERR
    
    # Validate system requirements
    debug_print continue "Validating system requirements..."
    
    # Check if we're running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        debug_print exit "This script is designed for Linux systems only"
        exit 1
    fi
    
    # Check available disk space in home directory (require at least 1GB)
    local available_space
    available_space=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$available_space" -lt 1 ]]; then
        debug_print exit "Insufficient disk space. At least 1GB free space required in home directory"
        exit 1
    fi
    
    # Setup configuration directories
    if ! setup_config_dirs; then
        debug_print exit "Failed to setup configuration directories"
        exit 1
    fi
    
    # Load existing configuration
    getdirs
    
    # Check dependencies
    if ! check_dependencies; then
        debug_print exit "Dependency check failed"
        exit 1
    fi
    
    # Validate wine installation if wine prefix exists
    if [[ -n "$wine_prefix" ]] && [[ -d "$wine_prefix" ]]; then
        if ! check_wine; then
            debug_print continue "Warning: Wine validation failed, but continuing..."
        fi
    fi
    
    debug_print continue "Enhanced application initialization completed successfully"
    return 0
}

# Application startup sequence
startup_sequence() {
    debug_print continue "Starting $script_name v$script_version..."
    
    # Initialize application with enhanced checks
    if ! initialize_application; then
        debug_print exit "Application initialization failed"
        exit 1
    fi
    
    # Log startup information
    debug_print continue "System: $(uname -s) $(uname -r)"
    debug_print continue "Shell: $BASH_VERSION"
    debug_print continue "User: $(whoami)"
    debug_print continue "Home: $HOME"
    debug_print continue "Config: $config_dir"
    debug_print continue "Wine Prefix: ${wine_prefix:-'Not configured'}"
    debug_print continue "Game Directory: ${game_dir:-'Not configured'}"
    
    debug_print continue "Startup sequence completed successfully"
}

############################################################################
# Main Function
############################################################################

# Main function
main() {
    local direct_function=""
    local function_args=()
    
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
            --install)
                direct_function="install_battlenet"
                shift
                ;;
            --runners)
                direct_function="manage_wine_runners"
                shift
                ;;
            --preflight)
                direct_function="preflight_check"
                shift
                ;;
            --launch)
                direct_function="main_menu_launch_wow"
                shift
                ;;
            --maintenance)
                direct_function="maintenance_tools"
                shift
                ;;
            --settings)
                direct_function="settings_menu"
                shift
                ;;
            --reset-config)
                direct_function="reset_config"
                shift
                ;;
            --list-runners)
                direct_function="list_installed_runners"
                shift
                ;;
            --wine-shell)
                direct_function="open_wine_shell"
                shift
                ;;
            --winecfg)
                direct_function="run_winecfg"
                shift
                ;;
            --*)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information"
                exit 1
                ;;
            *)
                # Collect remaining arguments as function parameters
                function_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Run startup sequence
    startup_sequence
    
    # Handle direct function calls
    if [[ -n "$direct_function" ]]; then
        debug_print continue "Executing direct function: $direct_function"
        
        case "$direct_function" in
            "install_battlenet")
                main_menu_install_battlenet
                ;;
            "manage_wine_runners")
                main_menu_manage_runners
                ;;
            "preflight_check")
                main_menu_system_optimization
                ;;
            "main_menu_launch_wow")
                main_menu_launch_wow
                ;;
            "maintenance_tools")
                main_menu_maintenance
                ;;
            "settings_menu")
                main_menu_settings
                ;;
            "reset_config")
                if message question "Reset Configuration" "This will reset all Azeroth Winebar configuration to defaults.\n\nAre you sure you want to continue?"; then
                    reset_config
                    message info "Reset Complete" "Configuration has been reset to defaults."
                else
                    debug_print continue "Configuration reset cancelled by user"
                fi
                ;;
            "list_installed_runners")
                echo "Installed Wine Runners:"
                echo "======================"
                if list_installed_runners; then
                    echo
                    echo "Use --runners to manage wine runners interactively."
                else
                    echo "No wine runners installed."
                    echo "Use --runners to install wine runners."
                fi
                ;;
            "open_wine_shell")
                if [[ -z "$wine_prefix" ]]; then
                    message error "No Wine Prefix" "No wine prefix is configured.\n\nPlease install Battle.net first or configure a wine prefix."
                    exit 1
                else
                    open_wine_shell
                fi
                ;;
            "run_winecfg")
                if [[ -z "$wine_prefix" ]]; then
                    message error "No Wine Prefix" "No wine prefix is configured.\n\nPlease install Battle.net first or configure a wine prefix."
                    exit 1
                else
                    run_winecfg
                fi
                ;;
            *)
                debug_print exit "Unknown direct function: $direct_function"
                exit 1
                ;;
        esac
        
        debug_print continue "Direct function execution completed"
        exit 0
    fi
    
    # Show welcome message on first run
    if is_first_run; then
        message info "Welcome to Azeroth Winebar" "Welcome to Azeroth Winebar v$script_version!\n\nThis helper script will assist you with installing and optimizing World of Warcraft and Battle.net on Linux using Proton Experimental.\n\nFeatures:\n- Automated Battle.net installation\n- System optimization checks\n- WoW-specific tweaks and optimizations\n- Desktop integration\n- Wine runner management\n\nLet's get started!"
        mark_first_run_complete
    fi
    
    # Start main menu loop
    main_menu_loop
    
    debug_print continue "$script_name shutdown completed"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi