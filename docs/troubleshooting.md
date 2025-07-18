# Azeroth Winebar Troubleshooting Guide

This guide helps you diagnose and resolve common issues with Azeroth Winebar and World of Warcraft on Linux.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Installation Issues](#installation-issues)
- [Launch Problems](#launch-problems)
- [Performance Issues](#performance-issues)
- [Graphics Problems](#graphics-problems)
- [Audio Issues](#audio-issues)
- [Network Problems](#network-problems)
- [System-Specific Issues](#system-specific-issues)
- [Advanced Troubleshooting](#advanced-troubleshooting)

## Quick Diagnostics

### System Compatibility Check

Run the system compatibility test first:

```bash
./tests/system-compatibility-tests.sh
```

This will identify most common system-level issues.

### Debug Mode

Enable debug output for detailed information:

```bash
export DEBUG=1
./azeroth-winebar.sh
```

### Log Files

Check these locations for error messages:

- **Launch logs**: `$WINEPREFIX/wow-launch.log`
- **Wine logs**: `$WINEPREFIX/wine.log`
- **System logs**: `journalctl -f` or `/var/log/syslog`

## Installation Issues

### Battle.net Installation Fails

#### Symptoms
- Installation hangs or crashes
- "Failed to download Battle.net installer" error
- Wine errors during installation

#### Solutions

1. **Check internet connection**:
   ```bash
   curl -I https://www.battle.net/
   ```

2. **Verify wine installation**:
   ```bash
   wine --version
   winetricks --version
   ```

3. **Clear wine prefix and retry**:
   ```bash
   rm -rf "$WINEPREFIX"
   ./azeroth-winebar.sh install_battlenet
   ```

4. **Manual Battle.net download**:
   ```bash
   # Download manually if automatic download fails
   wget -O /tmp/Battle.net-Setup.exe "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
   ```

### Wine Runner Installation Issues

#### Symptoms
- "Failed to download wine runner" error
- Wine runner not appearing in list
- Permission errors

#### Solutions

1. **Check GitHub API access**:
   ```bash
   curl -s https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases | head
   ```

2. **Manual runner installation**:
   ```bash
   # Download and extract manually
   mkdir -p ~/.local/share/azeroth-winebar/runners/
   # Extract to the runners directory
   ```

3. **Fix permissions**:
   ```bash
   chmod -R 755 ~/.local/share/azeroth-winebar/runners/
   ```

### Dependency Issues

#### Symptoms
- "Missing required dependencies" error
- Commands not found

#### Solutions

**Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install curl unzip cabextract zenity policykit-1 wine winetricks
```

**Fedora**:
```bash
sudo dnf install curl unzip cabextract zenity polkit wine winetricks
```

**Arch Linux**:
```bash
sudo pacman -S curl unzip cabextract zenity polkit wine winetricks
```

## Launch Problems

### Battle.net Won't Start

#### Symptoms
- Battle.net launcher doesn't appear
- Process starts but no window
- Immediate crash on launch

#### Solutions

1. **Check wine prefix**:
   ```bash
   ls -la "$WINEPREFIX"
   winecfg  # Should open wine configuration
   ```

2. **Verify Battle.net installation**:
   ```bash
   ls -la "$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/"
   ```

3. **Run Battle.net directly**:
   ```bash
   cd "$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/"
   wine "Battle.net Launcher.exe"
   ```

4. **Check for conflicting processes**:
   ```bash
   ps aux | grep -i battle
   pkill -f Battle.net  # Kill existing processes
   ```

### WoW Won't Launch from Battle.net

#### Symptoms
- Battle.net starts but WoW doesn't launch
- "Game is already running" error
- WoW process starts but no window

#### Solutions

1. **Check WoW installation**:
   ```bash
   ls -la "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/"
   ```

2. **Clear WoW cache**:
   ```bash
   rm -rf "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/Cache/"
   ```

3. **Reset WoW configuration**:
   ```bash
   mv "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/WTF/" \
      "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/WTF.backup/"
   ```

4. **Launch WoW directly**:
   ```bash
   cd "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/_retail_/"
   wine Wow.exe
   ```

### Desktop Entry Issues

#### Symptoms
- No Battle.net icon in application menu
- Desktop entry doesn't work
- Wrong application launches

#### Solutions

1. **Regenerate desktop entries**:
   ```bash
   ./azeroth-winebar.sh create_desktop_entry
   ```

2. **Manual desktop entry creation**:
   ```bash
   cat > ~/.local/share/applications/azeroth-winebar-wow.desktop << EOF
   [Desktop Entry]
   Name=World of Warcraft
   Exec=/path/to/azeroth-winebar/lib/wow-launch.sh
   Icon=battlenet-launcher
   Type=Application
   Categories=Game;
   EOF
   ```

3. **Update desktop database**:
   ```bash
   update-desktop-database ~/.local/share/applications/
   ```

## Performance Issues

### Low FPS / Poor Performance

#### Symptoms
- Consistently low frame rates
- Stuttering or lag
- High CPU/GPU usage

#### Solutions

1. **Check system requirements**:
   ```bash
   # Memory check
   free -h
   
   # CPU info
   lscpu
   
   # GPU info
   lspci | grep -i vga
   ```

2. **Verify DXVK is working**:
   ```bash
   # Check for DXVK files
   ls -la "$WINEPREFIX/drive_c/windows/system32/d3d11.dll"
   
   # Enable DXVK HUD
   export DXVK_HUD="fps,compiler"
   ```

3. **Optimize WoW settings**:
   - Lower graphics settings in-game
   - Disable addons temporarily
   - Check Config.wtf optimizations

4. **System optimizations**:
   ```bash
   # Check if optimizations are applied
   cat /proc/sys/vm/max_map_count  # Should be 16777216
   ulimit -n  # Should be 524288
   ```

### Memory Issues

#### Symptoms
- Out of memory errors
- System becomes unresponsive
- Swap usage very high

#### Solutions

1. **Check memory usage**:
   ```bash
   free -h
   htop  # Monitor memory usage
   ```

2. **Increase swap space**:
   ```bash
   # Create swap file (8GB example)
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

3. **Optimize wine memory usage**:
   ```bash
   export STAGING_SHARED_MEMORY=1
   export WINE_LARGE_ADDRESS_AWARE=1
   ```

### Shader Compilation Stutters

#### Symptoms
- Periodic stuttering during gameplay
- "Compiling shaders" messages
- Performance improves over time

#### Solutions

1. **Pre-compile shaders**:
   ```bash
   # Let the game run for 30+ minutes in different areas
   # Shaders will be cached for future use
   ```

2. **Optimize DXVK cache**:
   ```bash
   export DXVK_STATE_CACHE_PATH="$GAMEDIR"
   export DXVK_STATE_CACHE=1
   ```

3. **Share shader cache** (if you have multiple installations):
   ```bash
   # Copy shader cache between installations
   cp -r /path/to/working/cache/* "$GAMEDIR/"
   ```

## Graphics Problems

### Black Screen / No Display

#### Symptoms
- Game launches but screen is black
- Audio works but no video
- Cursor visible but no graphics

#### Solutions

1. **Check graphics drivers**:
   ```bash
   # NVIDIA
   nvidia-smi
   
   # AMD
   glxinfo | grep -i mesa
   
   # Intel
   glxinfo | grep -i intel
   ```

2. **Try different graphics APIs**:
   ```bash
   # Force DirectX 11
   export DXVK_CONFIG="dxgi.maxFrameLatency=1"
   
   # Try OpenGL mode
   # In WoW: System -> Advanced -> Graphics API -> OpenGL
   ```

3. **Disable hardware acceleration**:
   - In Battle.net settings
   - In WoW graphics settings

### Texture Issues

#### Symptoms
- Missing textures
- Corrupted graphics
- Flickering textures

#### Solutions

1. **Clear texture cache**:
   ```bash
   rm -rf "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/Cache/"
   ```

2. **Verify DXVK configuration**:
   ```bash
   cat "$GAMEDIR/dxvk.conf"
   # Should contain proper DXVK settings
   ```

3. **Update graphics drivers**:
   ```bash
   # Ubuntu/Debian (NVIDIA)
   sudo apt install nvidia-driver-470
   
   # Fedora (NVIDIA)
   sudo dnf install akmod-nvidia
   ```

### Multi-Monitor Issues

#### Symptoms
- Game appears on wrong monitor
- Resolution problems
- Cursor confined to wrong screen

#### Solutions

1. **Configure wine for multi-monitor**:
   ```bash
   winecfg
   # Graphics tab -> Configure monitors
   ```

2. **Use gamescope for window management**:
   ```bash
   export USE_GAMESCOPE=yes
   export GAMESCOPE_ARGS="-W 1920 -H 1080 -f"
   ```

3. **Set primary monitor**:
   ```bash
   xrandr --output HDMI-1 --primary
   ```

## Audio Issues

### No Sound

#### Symptoms
- No audio in game
- Audio works in other applications
- Wine audio test fails

#### Solutions

1. **Check wine audio configuration**:
   ```bash
   winecfg
   # Audio tab -> Test Sound
   ```

2. **Install audio dependencies**:
   ```bash
   # Ubuntu/Debian
   sudo apt install pulseaudio-utils pavucontrol
   
   # Fedora
   sudo dnf install pulseaudio-utils pavucontrol
   ```

3. **Configure PulseAudio**:
   ```bash
   # Check audio devices
   pactl list sinks
   
   # Set default sink
   pactl set-default-sink alsa_output.pci-0000_00_1f.3.analog-stereo
   ```

### Audio Crackling / Distortion

#### Symptoms
- Crackling or popping sounds
- Audio cuts out intermittently
- Distorted audio

#### Solutions

1. **Adjust audio buffer size**:
   ```bash
   export PULSE_LATENCY_MSEC=60
   ```

2. **Configure wine audio**:
   ```bash
   winecfg
   # Audio tab -> Advanced -> Default sample rate: 44100
   ```

3. **Use ALSA instead of PulseAudio**:
   ```bash
   # In winecfg, select ALSA driver
   ```

## Network Problems

### Connection Issues

#### Symptoms
- Can't connect to Battle.net
- Frequent disconnections
- Login failures

#### Solutions

1. **Check firewall settings**:
   ```bash
   # Ubuntu/Debian
   sudo ufw status
   sudo ufw allow 1119/tcp  # Battle.net
   sudo ufw allow 3724/tcp  # WoW
   
   # Fedora
   sudo firewall-cmd --list-all
   sudo firewall-cmd --add-port=1119/tcp --permanent
   sudo firewall-cmd --add-port=3724/tcp --permanent
   ```

2. **DNS configuration**:
   ```bash
   # Try different DNS servers
   echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
   ```

3. **Network troubleshooting**:
   ```bash
   # Test connectivity
   ping battle.net
   telnet us.battle.net 1119
   ```

### Slow Download Speeds

#### Symptoms
- Very slow game downloads
- Battle.net downloads pause/resume
- Timeout errors

#### Solutions

1. **Configure Battle.net bandwidth**:
   - Battle.net Settings -> Game Install/Update
   - Set bandwidth limit appropriately

2. **Change download region**:
   - Battle.net Settings -> Game Install/Update
   - Try different regions

3. **Network optimization**:
   ```bash
   # Increase network buffers
   echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
   echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```

## System-Specific Issues

### Ubuntu/Debian Issues

#### Snap Package Conflicts
```bash
# Remove snap wine if installed
sudo snap remove wine-platform-runtime
sudo snap remove wine-platform-5-stable

# Install wine from repository
sudo apt install wine
```

#### AppArmor Issues
```bash
# Check AppArmor status
sudo aa-status

# Disable AppArmor for wine (if needed)
sudo aa-disable /usr/bin/wine
```

### Fedora Issues

#### SELinux Problems
```bash
# Check SELinux status
sestatus

# Set SELinux to permissive (temporary)
sudo setenforce 0

# Permanent (not recommended)
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### Arch Linux Issues

#### Missing 32-bit Libraries
```bash
# Enable multilib repository
sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
sudo pacman -Sy

# Install 32-bit libraries
sudo pacman -S lib32-mesa lib32-vulkan-radeon lib32-vulkan-intel
```

## Advanced Troubleshooting

### Wine Debugging

#### Enable Wine Debug Output
```bash
export WINEDEBUG="+all"
wine program.exe 2>&1 | tee wine-debug.log
```

#### Specific Debug Channels
```bash
# Debug specific components
export WINEDEBUG="+d3d,+dxgi,+vulkan"
export WINEDEBUG="+registry,+dll"
export WINEDEBUG="+heap,+virtual"
```

### Process Monitoring

#### Monitor Wine Processes
```bash
# Watch wine processes
watch -n 1 'ps aux | grep wine'

# Monitor system resources
htop
iotop  # I/O monitoring
```

#### Wine Process Management
```bash
# Kill all wine processes
wineserver -k

# Force kill wine processes
pkill -f wine
pkill -f Battle.net
```

### Registry Debugging

#### Export Wine Registry
```bash
wine regedit /E wine-registry-backup.reg
```

#### Check Specific Registry Keys
```bash
wine reg query "HKEY_CURRENT_USER\Software\Wine\DllOverrides"
wine reg query "HKEY_CURRENT_USER\Software\Blizzard Entertainment"
```

### File System Issues

#### Check Disk Space
```bash
df -h "$WINEPREFIX"
df -h "$HOME"
```

#### File Permissions
```bash
# Fix wine prefix permissions
chmod -R 755 "$WINEPREFIX"
chown -R $USER:$USER "$WINEPREFIX"
```

#### File System Type Issues
```bash
# Check file system type
df -T "$WINEPREFIX"

# Some file systems (like FAT32) don't support wine properly
# Use ext4, btrfs, or other Linux-native file systems
```

## Getting Help

### Information to Gather

When seeking help, provide:

1. **System information**:
   ```bash
   ./tests/system-compatibility-tests.sh > system-info.txt
   ```

2. **Error logs**:
   ```bash
   export DEBUG=1
   ./azeroth-winebar.sh 2>&1 | tee error-log.txt
   ```

3. **Wine configuration**:
   ```bash
   wine --version
   winecfg  # Screenshot of configuration
   ```

### Support Channels

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For general questions
- **Wine AppDB**: For wine-specific issues
- **Distribution forums**: For system-specific problems

### Creating Bug Reports

Include in your bug report:

1. **Steps to reproduce** the issue
2. **Expected behavior** vs actual behavior
3. **System information** (OS, hardware, wine version)
4. **Error logs** with debug output enabled
5. **Screenshots** if applicable

This troubleshooting guide should help you resolve most common issues with Azeroth Winebar and World of Warcraft on Linux.