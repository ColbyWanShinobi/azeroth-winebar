#!/usr/bin/env bash

################################################################################
# This script launches World of Warcraft via Battle.net using Wine.
# It is meant to be used after installation via the Azeroth Winebar.
#
# The following .desktop files are added by wine during installation and then
# modified by the Azeroth Winebar to call this script.
# They are automatically detected by most desktop environments for easy game
# launching.
#
################################################################################
# $HOME/Desktop/Battle.net.desktop
# $HOME/.local/share/applications/wine/Programs/Battle.net/Battle.net.desktop
################################################################################
#
# If you do not wish to use the above .desktop files, simply run this script
# from your terminal.
#
# version: 1.0
################################################################################

################################################################
# Configure the environment
# Add additional environment variables here as needed
################################################################

# Load configuration from azeroth-winebar config files
config_dir="$HOME/.config/azeroth-winebar"

# Load wine prefix path
if [[ -f "$config_dir/winedir.conf" ]]; then
    export WINEPREFIX="$(cat "$config_dir/winedir.conf" 2>/dev/null)"
else
    export WINEPREFIX="$HOME/Games/world-of-warcraft"
fi

# Load game directory path
if [[ -f "$config_dir/gamedir.conf" ]]; then
    GAMEDIR="$(cat "$config_dir/gamedir.conf" 2>/dev/null)"
else
    GAMEDIR="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net"
fi

launch_log="$WINEPREFIX/wow-launch.log"

# Wine configuration
export WINEDLLOVERRIDES="winemenubuilder.exe=d;nvapi=disabled;nvapi64=disabled" # Prevent updates from overwriting .desktop entries and disable nvapi
export WINEDEBUG=-all # Cut down on console debug messages
export WINEARCH="win64"
export WINE_LARGE_ADDRESS_AWARE=1

# DXVK Configuration
export DXVK_CONFIG_FILE="$GAMEDIR/dxvk.conf"
export DXVK_HUD="compiler"
export DXVK_STATE_CACHE_PATH="$GAMEDIR"

# Wine Staging optimizations
export STAGING_SHARED_MEMORY=1

# Nvidia cache options
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_PATH="$GAMEDIR"
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_DXVK_OPTIMIZATIONS=1

# Mesa (AMD/Intel) shader cache options
export MESA_SHADER_CACHE_DIR="$GAMEDIR"
export MESA_SHADER_CACHE_MAX_SIZE="10G"

# Optional HUDs (uncomment to enable)
#export DXVK_HUD=fps,compiler
#export MANGOHUD=1

################################################################
# Configure the wine binaries to be used
#
# To use a custom wine runner, set the path to its bin directory
# export wine_path="/path/to/custom/runner/bin"
################################################################
export wine_path="$(command -v wine | xargs dirname)"

#############################################
# Command line arguments
#############################################
# shell - Drop into a Wine maintenance shell
# config - Wine configuration
# controllers - Game controller configuration
# Usage: ./wow-launch.sh shell
case "$1" in
    "shell")
        echo "Entering Wine prefix maintenance shell. Type 'exit' when done."
        export PATH="$wine_path:$PATH"; export PS1="Wine: "
        cd "$WINEPREFIX"; pwd; /usr/bin/env bash --norc; exit 0
        ;;
    "config")
        /usr/bin/env bash --norc -c "${wine_path}/winecfg"; exit 0
        ;;
    "controllers")
        /usr/bin/env bash --norc -c "${wine_path}/wine control joy.cpl"; exit 0
        ;;
esac

#############################################
# Run optional prelaunch and postexit scripts
#############################################
# To use, update the game install paths here, create the scripts with your
# desired actions in them, then place them in your prefix directory:
# wow-prelaunch.sh and wow-postexit.sh
# Replace the trap line in the section below with the example provided here
#
# "$WINEPREFIX/wow-prelaunch.sh"
# trap "update_check; \"$wine_path\"/wineserver -k; \"$WINEPREFIX\"/wow-postexit.sh" EXIT

#############################################
# Shader Cache Configuration
#############################################
setup_shader_cache() {
    debug_print() {
        if [[ "${DEBUG:-0}" == "1" ]]; then
            echo "[DEBUG] $*" >&2
        fi
    }
    
    debug_print "Setting up shader cache configuration..."
    
    # Create DXVK configuration file if it doesn't exist
    if [[ ! -f "$GAMEDIR/dxvk.conf" ]]; then
        debug_print "Creating DXVK configuration file..."
        cat > "$GAMEDIR/dxvk.conf" << EOF
# DXVK Configuration for World of Warcraft
# Optimized for Battle.net and WoW performance

# Enable state cache for faster loading
dxvk.enableStateCache = True

# Optimize for WoW's rendering patterns
dxvk.numCompilerThreads = 0
dxvk.useRawSsbo = True

# Memory optimizations
dxvk.maxFrameLatency = 1
dxvk.tearFree = False

# Logging (disable for production)
dxvk.logLevel = none
EOF
        debug_print "DXVK configuration created"
    fi
    
    # Ensure shader cache directories exist
    mkdir -p "$GAMEDIR/shader_cache"
    mkdir -p "$WINEPREFIX/shader_cache"
    
    debug_print "Shader cache setup completed"
}

#############################################
# Wine Process Management
#############################################
cleanup_wine_processes() {
    debug_print() {
        if [[ "${DEBUG:-0}" == "1" ]]; then
            echo "[DEBUG] $*" >&2
        fi
    }
    
    debug_print "Starting wine process cleanup..."
    
    # Wait for Battle.net processes to finish
    local max_wait=30
    local wait_count=0
    
    while [[ $wait_count -lt $max_wait ]]; do
        if ! "$wine_path"/winedbg --command "info proc" 2>/dev/null | grep -qi "battle\.net\|blizzard\|wow"; then
            debug_print "No Battle.net/WoW processes found, cleanup complete"
            break
        fi
        debug_print "Waiting for Battle.net/WoW processes to finish... ($wait_count/$max_wait)"
        sleep 2
        ((wait_count++))
    done
    
    if [[ $wait_count -ge $max_wait ]]; then
        debug_print "Timeout reached, forcing wine process termination"
    fi
    
    # Kill wine server to ensure clean shutdown
    "$wine_path"/wineserver -k 2>/dev/null || true
    
    debug_print "Wine process cleanup completed"
}

#############################################
# Optional Performance Tools Integration
#############################################
check_performance_tools() {
    debug_print() {
        if [[ "${DEBUG:-0}" == "1" ]]; then
            echo "[DEBUG] $*" >&2
        fi
    }
    
    # Check for gamemode
    if command -v gamemoderun >/dev/null 2>&1; then
        debug_print "GameMode detected and available"
        export GAMEMODE_AVAILABLE=1
    else
        debug_print "GameMode not available"
        export GAMEMODE_AVAILABLE=0
    fi
    
    # Check for gamescope
    if command -v gamescope >/dev/null 2>&1; then
        debug_print "Gamescope detected and available"
        export GAMESCOPE_AVAILABLE=1
    else
        debug_print "Gamescope not available"
        export GAMESCOPE_AVAILABLE=0
    fi
}

#############################################
# Launch Command Builder
#############################################
build_launch_command() {
    local base_command="\"$wine_path\"/wine \"C:\\Program Files (x86)\\Battle.net\\Battle.net Launcher.exe\""
    local launch_command=""
    
    debug_print() {
        if [[ "${DEBUG:-0}" == "1" ]]; then
            echo "[DEBUG] $*" >&2
        fi
    }
    
    # Check for performance tool preferences
    local use_gamemode="${USE_GAMEMODE:-auto}"
    local use_gamescope="${USE_GAMESCOPE:-no}"
    local gamescope_args="${GAMESCOPE_ARGS:---hdr-enabled -W 2560 -H 1440 --force-grab-cursor}"
    
    # Build command with optional performance tools
    if [[ "$use_gamescope" == "yes" && "$GAMESCOPE_AVAILABLE" == "1" ]]; then
        debug_print "Using gamescope with args: $gamescope_args"
        launch_command="gamescope $gamescope_args"
        
        if [[ "$use_gamemode" == "yes" || ("$use_gamemode" == "auto" && "$GAMEMODE_AVAILABLE" == "1") ]]; then
            debug_print "Adding gamemode to gamescope command"
            launch_command="$launch_command gamemoderun"
        fi
        
        launch_command="$launch_command $base_command"
    elif [[ "$use_gamemode" == "yes" || ("$use_gamemode" == "auto" && "$GAMEMODE_AVAILABLE" == "1") ]]; then
        debug_print "Using gamemode only"
        launch_command="gamemoderun $base_command"
    else
        debug_print "Using standard launch command"
        launch_command="$base_command"
    fi
    
    echo "$launch_command"
}

#############################################
# It's a trap!
#############################################
# Kill the wine prefix when this script exits
# This makes sure there will be no lingering background wine processes
trap "cleanup_wine_processes" EXIT

#############################################
# Initialize and Launch Battle.net
#############################################

# Setup shader cache configuration
setup_shader_cache

# Check for available performance tools
check_performance_tools

# Build optimized launch command
launch_command=$(build_launch_command)

# Execute the launch command
echo "Launching Battle.net with command: $launch_command" >> "$launch_log"
eval "$launch_command" >> "$launch_log" 2>&1