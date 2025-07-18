# Azeroth Winebar

A Linux helper script for managing and optimizing World of Warcraft and Battle.net on Linux systems using Wine/Proton Experimental.

## Overview

Azeroth Winebar is a bash-based helper script that provides a user-friendly interface for installing, configuring, and optimizing World of Warcraft and Battle.net on Linux systems. Based on the proven lug-helper architecture, this tool has been specifically adapted for Blizzard's Battle.net launcher and World of Warcraft, incorporating all existing wine-related tweaks while adding Battle.net-specific optimizations.

### Key Features

- **Automated Battle.net Installation**: Complete setup of Battle.net launcher with optimized configuration
- **Proton Experimental Support**: Uses Proton Experimental as the default wine runner for best compatibility
- **System Optimization**: Automatic system tuning for optimal WoW performance
- **Wine Runner Management**: Install, manage, and switch between different wine runners
- **GUI and Terminal Support**: Works with both graphical (Zenity) and terminal interfaces
- **Comprehensive Testing**: Full test suite for reliability and compatibility
- **Cross-Distribution Support**: Works on Ubuntu, Fedora, Arch, openSUSE, and more

## Quick Start

### Prerequisites

- Linux distribution (64-bit)
- At least 16GB RAM (40GB RAM + swap recommended)
- 50GB+ free disk space
- Internet connection

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/azeroth-winebar.git
   cd azeroth-winebar
   ```

2. **Make the script executable:**
   ```bash
   chmod +x azeroth-winebar.sh
   ```

3. **Run the script:**
   ```bash
   ./azeroth-winebar.sh
   ```

### First Run

On first run, Azeroth Winebar will:

1. Check for required dependencies
2. Perform system optimization checks
3. Guide you through Battle.net installation
4. Set up wine prefix with optimizations
5. Create launch scripts and desktop entries

## System Requirements

### Minimum Requirements

- **OS**: 64-bit Linux distribution
- **RAM**: 16GB (for basic functionality)
- **Storage**: 50GB free space
- **Graphics**: DirectX 11 compatible GPU

### Recommended Requirements

- **RAM**: 32GB+ (or 16GB RAM + 24GB swap)
- **Storage**: 100GB+ free space (SSD recommended)
- **Graphics**: Modern GPU with Vulkan support
- **Network**: Stable broadband connection

### Supported Distributions

- **Ubuntu/Debian**: 20.04+ / Bullseye+
- **Fedora**: 35+
- **Arch Linux**: Rolling release
- **openSUSE**: Leap 15.4+ / Tumbleweed
- **Other**: Most modern Linux distributions

## Dependencies

### Required Dependencies

These packages are required for basic functionality:

- `bash` (4.0+)
- `curl`
- `unzip`
- `coreutils`

### Optional Dependencies

These packages enable additional features:

- `zenity` - GUI dialog support
- `cabextract` - Required for winetricks
- `polkit` - Privilege escalation for system optimizations
- `wine` - Wine compatibility layer (or use built-in runner management)
- `winetricks` - Wine configuration utility

### Installation Commands

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install curl unzip cabextract zenity policykit-1
```

**Fedora:**
```bash
sudo dnf install curl unzip cabextract zenity polkit
```

**Arch Linux:**
```bash
sudo pacman -S curl unzip cabextract zenity polkit
```

**openSUSE:**
```bash
sudo zypper install curl unzip cabextract zenity polkit
```

## Usage

### Main Menu Options

1. **Install Battle.net** - Complete Battle.net and WoW installation
2. **Manage Wine Runners** - Install, delete, or switch wine runners
3. **System Optimization** - Check and apply system optimizations
4. **Launch WoW** - Start Battle.net/World of Warcraft
5. **Maintenance Tools** - Wine configuration, DXVK updates, troubleshooting
6. **Settings** - Configure directories and preferences

### Command Line Usage

You can also run specific functions directly:

```bash
# Install Battle.net
./azeroth-winebar.sh install_battlenet

# Check system requirements
./azeroth-winebar.sh preflight_check

# Launch WoW
./azeroth-winebar.sh launch_wow

# Show help
./azeroth-winebar.sh --help
```

### Launch Scripts

After installation, you can launch WoW using:

- **Desktop Entry**: Look for "Battle.net" in your application menu
- **Launch Script**: `./lib/wow-launch.sh`
- **Direct Command**: `./azeroth-winebar.sh launch_wow`

## Configuration

### Configuration Files

Azeroth Winebar stores configuration in `~/.config/azeroth-winebar/`:

- `winedir.conf` - Wine prefix path
- `gamedir.conf` - Game installation directory
- `firstrun.conf` - First run completion flag
- `keybinds/` - WoW keybind backups

### Wine Runners

Wine runners are installed in `~/.local/share/azeroth-winebar/runners/`:

- **Proton Experimental** - Default runner (requires Steam)
- **Lutris GE** - Gaming-optimized wine builds
- **Wine TKG** - Custom wine builds
- **Proton GE** - Community Proton builds

### Environment Variables

You can customize behavior with environment variables:

```bash
# Enable debug output
export DEBUG=1

# Force terminal mode (disable GUI)
export FORCE_TERMINAL=1

# Custom wine prefix location
export WINEPREFIX="/path/to/custom/prefix"

# Enable performance tools
export USE_GAMEMODE=yes
export USE_GAMESCOPE=yes
```

## Optimizations Applied

### System Optimizations

- **vm.max_map_count**: Set to 16777216 for memory mapping
- **File Descriptors**: Increased limits for wine processes
- **Memory Management**: Optimized for large applications

### Wine Optimizations

- **DXVK Configuration**: Optimized for WoW rendering
- **Registry Tweaks**: Disabled problematic components (nvapi)
- **Environment Variables**: Performance and compatibility settings
- **Font Installation**: Arial font for proper text rendering

### Battle.net Optimizations

- **Hardware Acceleration**: Disabled to prevent crashes
- **Streaming**: Disabled unnecessary features
- **Background Processes**: Minimized resource usage
- **Launch Behavior**: Optimized for gaming

### WoW-Specific Tweaks

- **worldPreloadNonCritical**: Set to 0 for faster loading
- **rawMouseEnable**: Enabled for proper cursor behavior
- **Shader Cache**: Optimized for both NVIDIA and AMD GPUs

## Troubleshooting

### Common Issues

**Battle.net won't start:**
- Check wine prefix permissions
- Verify Battle.net installation
- Run `./azeroth-winebar.sh winecfg` to check wine configuration

**Poor performance:**
- Ensure system optimizations are applied
- Check graphics drivers are up to date
- Verify DXVK is properly configured

**Audio issues:**
- Install PulseAudio or PipeWire support in wine
- Check audio device selection in winecfg

**Crashes or freezes:**
- Check system logs for errors
- Verify memory requirements are met
- Try different wine runners

### Debug Mode

Enable debug output for troubleshooting:

```bash
export DEBUG=1
./azeroth-winebar.sh
```

### Log Files

Check these locations for logs:

- `~/.wine-prefix/wow-launch.log` - Launch script logs
- `~/.config/azeroth-winebar/` - Configuration files
- System logs via `journalctl` or `/var/log/`

### Getting Help

1. **Check the logs** for error messages
2. **Run system compatibility tests**: `./tests/system-compatibility-tests.sh`
3. **Verify dependencies** are installed
4. **Check wine configuration** with winecfg
5. **Search existing issues** on GitHub
6. **Create a new issue** with detailed information

## Testing

Azeroth Winebar includes a comprehensive test suite to ensure reliability:

### Running Tests

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suite
./tests/run-all-tests.sh --suite=unit
./tests/run-all-tests.sh --suite=integration
./tests/run-all-tests.sh --suite=compatibility

# Verbose output
./tests/run-all-tests.sh --verbose
```

### Test Suites

- **Unit Tests**: Test individual functions and components
- **Integration Tests**: Test complete workflows and interactions
- **System Compatibility Tests**: Verify system requirements and compatibility

## Contributing

We welcome contributions to Azeroth Winebar! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the test suite
5. Submit a pull request

### Code Style

- Follow bash best practices
- Use meaningful variable names
- Add comments for complex logic
- Include tests for new features
- Update documentation as needed

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **lug-helper project** - Original codebase foundation
- **Lutris** - Wine runner management inspiration
- **DXVK project** - Graphics optimization layer
- **Wine project** - Windows compatibility layer
- **Proton** - Steam's wine distribution
- **Community contributors** - Bug reports, testing, and improvements

## Support

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Community support and questions
- **Wiki**: Additional documentation and guides

---

**Disclaimer**: This project is not affiliated with Blizzard Entertainment. World of Warcraft and Battle.net are trademarks of Blizzard Entertainment, Inc.