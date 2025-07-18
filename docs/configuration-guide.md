# Azeroth Winebar Configuration Guide

This guide covers advanced configuration options and customization for Azeroth Winebar.

## Table of Contents

- [Configuration Files](#configuration-files)
- [Wine Configuration](#wine-configuration)
- [System Optimizations](#system-optimizations)
- [Environment Variables](#environment-variables)
- [Custom Wine Runners](#custom-wine-runners)
- [Performance Tuning](#performance-tuning)
- [Advanced Settings](#advanced-settings)

## Configuration Files

Azeroth Winebar stores its configuration in `~/.config/azeroth-winebar/`:

### Core Configuration Files

#### `winedir.conf`
Contains the path to your wine prefix:
```
/home/username/Games/world-of-warcraft
```

#### `gamedir.conf`
Contains the path to your game installation directory:
```
/home/username/Games/world-of-warcraft/drive_c/Program Files (x86)/Battle.net
```

#### `firstrun.conf`
Marks whether the initial setup has been completed:
```
completed
```

### Backup Directory

#### `keybinds/`
Directory containing WoW keybind backups:
- Automatically created during installation
- Used to restore keybinds after updates
- Can be manually managed

## Wine Configuration

### Wine Prefix Structure

Your wine prefix is organized as follows:

```
~/.wine-prefix/
├── drive_c/
│   ├── Program Files (x86)/
│   │   └── Battle.net/
│   └── users/
├── system.reg
├── user.reg
└── userdef.reg
```

### Wine Registry Settings

Azeroth Winebar applies these registry modifications:

#### DXVA2 Backend (Wine Staging)
```reg
[HKEY_CURRENT_USER\Software\Wine\DXVA2]
"backend"="va"
```

#### NVAPI Overrides
```reg
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"nvapi"="disabled"
"nvapi64"="disabled"
```

### Manual Wine Configuration

Access wine configuration tools:

```bash
# Wine configuration GUI
./azeroth-winebar.sh winecfg

# Wine registry editor
./azeroth-winebar.sh regedit

# Wine control panel
./azeroth-winebar.sh control
```

## System Optimizations

### Memory Management

#### vm.max_map_count
Increased to handle large memory mappings:

```bash
# Current value
cat /proc/sys/vm/max_map_count

# Azeroth Winebar sets this to:
# vm.max_map_count = 16777216
```

#### File Descriptor Limits
Increased for wine processes:

```bash
# Check current limits
ulimit -n  # soft limit
ulimit -Hn # hard limit

# Azeroth Winebar configuration:
# Hard limit: 524288
# Soft limit: 524288
```

### Persistent System Changes

#### Sysctl Configuration
File: `/etc/sysctl.d/99-azeroth-winebar.conf`
```
# Azeroth Winebar - System optimizations for World of Warcraft
vm.max_map_count=16777216
```

#### Limits Configuration
File: `/etc/security/limits.d/99-azeroth-winebar.conf`
```
# Azeroth Winebar - File descriptor limits for WoW
* soft nofile 524288
* hard nofile 524288
```

### Manual System Optimization

Apply optimizations manually:

```bash
# Temporary (until reboot)
sudo sysctl vm.max_map_count=16777216

# Permanent
echo 'vm.max_map_count=16777216' | sudo tee /etc/sysctl.d/99-azeroth-winebar.conf
sudo sysctl -p /etc/sysctl.d/99-azeroth-winebar.conf
```

## Environment Variables

### Core Variables

#### Wine Environment
```bash
export WINEPREFIX="/path/to/wine/prefix"
export WINEARCH="win64"
export WINEDLLOVERRIDES="nvapi=disabled;nvapi64=disabled"
export WINEDEBUG="-all"
```

#### DXVK Configuration
```bash
export DXVK_CONFIG_FILE="$GAMEDIR/dxvk.conf"
export DXVK_HUD="compiler"
export DXVK_STATE_CACHE_PATH="$GAMEDIR"
```

#### Graphics Optimization
```bash
# NVIDIA
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="$GAMEDIR"
export __GL_DXVK_OPTIMIZATIONS=1

# AMD/Mesa
export MESA_SHADER_CACHE_DIR="$GAMEDIR"
export MESA_SHADER_CACHE_MAX_SIZE="10G"
```

### Custom Environment Variables

#### Debug Mode
```bash
export DEBUG=1
./azeroth-winebar.sh
```

#### Force Terminal Mode
```bash
export FORCE_TERMINAL=1
./azeroth-winebar.sh
```

#### Performance Tools
```bash
export USE_GAMEMODE=yes
export USE_GAMESCOPE=yes
export GAMESCOPE_ARGS="--hdr-enabled -W 2560 -H 1440"
```

## Custom Wine Runners

### Wine Runner Directory Structure

```
~/.local/share/azeroth-winebar/runners/
├── proton-experimental/
│   ├── bin/wine
│   └── .runner-info
├── lutris-ge-8.0/
│   ├── bin/wine
│   └── .runner-info
└── wine-tkg-8.0/
    ├── bin/wine
    └── .runner-info
```

### Runner Info File Format

`.runner-info` contains metadata:
```
RUNNER_NAME=proton-experimental
RUNNER_TYPE=proton-experimental
INSTALL_DATE=2024-01-15T10:30:00+00:00
WINE_BINARY=/home/user/.local/share/azeroth-winebar/runners/proton-experimental/bin/wine
```

### Adding Custom Runners

#### Manual Installation
1. Extract wine runner to runners directory
2. Create `.runner-info` file
3. Ensure wine binary is executable

#### Supported Runner Types
- `lutris-ge` - Lutris Gaming Edition
- `lutris-fshack` - Lutris with fsync patches
- `wine-tkg` - Custom wine builds
- `proton-ge` - GloriousEggroll Proton
- `proton-experimental` - Steam Proton Experimental

### Runner Selection

#### Set Default Runner
```bash
# Via menu system
./azeroth-winebar.sh
# Select "Manage Wine Runners" -> "Set Default Runner"

# Via command line
export WINE_RUNNER="lutris-ge-8.0"
```

## Performance Tuning

### DXVK Configuration

#### DXVK Config File
File: `$GAMEDIR/dxvk.conf`
```ini
# DXVK Configuration for World of Warcraft
dxvk.enableStateCache = True
dxvk.numCompilerThreads = 0
dxvk.useRawSsbo = True
dxvk.maxFrameLatency = 1
dxvk.tearFree = False
dxvk.logLevel = none
```

#### DXVK Environment Variables
```bash
# Enable state cache
export DXVK_STATE_CACHE=1

# Compiler threads (0 = auto)
export DXVK_COMPILER_THREADS=0

# HUD options
export DXVK_HUD="fps,compiler,memory"
```

### Battle.net Configuration

#### Battle.net.config
File: `$WINEPREFIX/drive_c/users/$USER/Application Data/Battle.net/Battle.net.config`

```json
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
    }
  }
}
```

### WoW Configuration

#### Config.wtf Optimizations
File: `$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/_retail_/WTF/Config.wtf`

```
SET worldPreloadNonCritical "0"
SET rawMouseEnable "1"
SET gxApi "d3d11"
SET ffxGlow "0"
SET ffxDeath "0"
```

### Graphics Settings

#### NVIDIA Optimizations
```bash
# Shader cache
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_PATH="$GAMEDIR"

# Performance
export __GL_DXVK_OPTIMIZATIONS=1
export __GL_YIELD="USLEEP"
```

#### AMD Optimizations
```bash
# Mesa shader cache
export MESA_SHADER_CACHE_DIR="$GAMEDIR"
export MESA_SHADER_CACHE_MAX_SIZE="10G"

# RadeonSI optimizations
export RADV_PERFTEST="aco"
export ACO_DEBUG="validateir,validatera"
```

## Advanced Settings

### Launch Script Customization

#### Custom Launch Arguments
Edit `lib/wow-launch.sh`:

```bash
# Add custom wine arguments
wine_args="--some-custom-arg"

# Modify launch command
"$wine_path"/wine $wine_args "C:\\Program Files (x86)\\Battle.net\\Battle.net Launcher.exe"
```

#### Performance Tools Integration
```bash
# GameMode integration
if [[ "$USE_GAMEMODE" == "yes" && "$GAMEMODE_AVAILABLE" == "1" ]]; then
    launch_command="gamemoderun $launch_command"
fi

# Gamescope integration
if [[ "$USE_GAMESCOPE" == "yes" && "$GAMESCOPE_AVAILABLE" == "1" ]]; then
    launch_command="gamescope $GAMESCOPE_ARGS $launch_command"
fi
```

### Desktop Integration

#### Custom Desktop Entry
File: `~/.local/share/applications/azeroth-winebar-wow.desktop`

```ini
[Desktop Entry]
Name=World of Warcraft
Comment=Launch World of Warcraft via Azeroth Winebar
Exec=/path/to/azeroth-winebar/lib/wow-launch.sh
Icon=battlenet-launcher
Terminal=false
Type=Application
Categories=Game;
```

### Backup and Restore

#### Configuration Backup
```bash
# Backup configuration
tar -czf azeroth-winebar-config-backup.tar.gz ~/.config/azeroth-winebar/

# Restore configuration
tar -xzf azeroth-winebar-config-backup.tar.gz -C ~/
```

#### Wine Prefix Backup
```bash
# Backup wine prefix (warning: can be very large)
tar -czf wine-prefix-backup.tar.gz "$WINEPREFIX"

# Restore wine prefix
tar -xzf wine-prefix-backup.tar.gz -C /path/to/restore/
```

### Troubleshooting Configuration

#### Reset Configuration
```bash
# Reset Azeroth Winebar configuration
./azeroth-winebar.sh reset_config

# Reset wine prefix (nuclear option)
rm -rf "$WINEPREFIX"
./azeroth-winebar.sh install_battlenet
```

#### Verify Configuration
```bash
# Check configuration files
ls -la ~/.config/azeroth-winebar/

# Verify wine prefix
ls -la "$WINEPREFIX"

# Test wine functionality
"$WINEPREFIX"/drive_c/windows/system32/winver.exe
```

## Configuration Examples

### High-Performance Setup
```bash
# Environment variables for maximum performance
export DXVK_HUD="compiler"
export __GL_SHADER_DISK_CACHE=1
export USE_GAMEMODE=yes
export WINE_CPU_TOPOLOGY="4:2"  # 4 cores, 2 threads each
```

### Low-Resource Setup
```bash
# Environment variables for lower-end systems
export DXVK_HUD=""
export WINE_CPU_TOPOLOGY="2:1"  # 2 cores, 1 thread each
export STAGING_SHARED_MEMORY=0
```

### Debug Setup
```bash
# Environment variables for debugging
export DEBUG=1
export WINEDEBUG="+all"
export DXVK_LOG_LEVEL="info"
export DXVK_HUD="full"
```

This configuration guide should help you customize Azeroth Winebar to your specific needs and system requirements.