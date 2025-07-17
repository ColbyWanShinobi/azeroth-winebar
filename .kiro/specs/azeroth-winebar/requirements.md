# Requirements Document

## Introduction

The azeroth-winebar project is a Linux helper script for managing and optimizing World of Warcraft and Battle.net on Linux systems. Based on the lug-helper codebase, this tool will be adapted specifically for Blizzard's Battle.net launcher and World of Warcraft, incorporating all existing wine-related tweaks while adding Battle.net-specific optimizations and requiring Proton Experimental as the default wine runner.

## Requirements

### Requirement 1

**User Story:** As a Linux gamer, I want a helper script that manages World of Warcraft installation and optimization, so that I can easily run WoW on Linux with optimal performance.

#### Acceptance Criteria

1. WHEN the user runs the script THEN the system SHALL display a GUI menu (with terminal fallback) for managing WoW installation
2. WHEN the user selects installation options THEN the system SHALL guide them through Battle.net and WoW setup
3. WHEN the script runs THEN the system SHALL check for required dependencies and system optimizations
4. IF dependencies are missing THEN the system SHALL notify the user and provide installation guidance

### Requirement 2

**User Story:** As a Linux user, I want the script to use Proton Experimental as the default wine runner, so that I get the best compatibility and performance for Battle.net and WoW.

#### Acceptance Criteria

1. WHEN the user installs wine runners THEN the system SHALL include Proton Experimental as an available option
2. WHEN no wine runner is specified THEN the system SHALL default to Proton Experimental
3. WHEN Proton Experimental is selected THEN the system SHALL download and configure it properly
4. WHEN the system checks wine requirements THEN the system SHALL validate Proton Experimental compatibility

### Requirement 3

**User Story:** As a WoW player, I want all Battle.net and WoW-specific wine tweaks applied automatically, so that the game runs optimally without manual configuration.

#### Acceptance Criteria

1. WHEN installing Battle.net THEN the system SHALL apply DXVK optimizations with proper environment variables
2. WHEN configuring the wine prefix THEN the system SHALL disable nvapi and nvapi64 overrides
3. WHEN setting up Battle.net THEN the system SHALL install Arial font to fix blurry text issues
4. WHEN configuring WoW THEN the system SHALL set worldPreloadNonCritical to 0 in Config.wtf
5. WHEN launching WoW THEN the system SHALL enable rawMouseEnable to fix cursor reset issues
6. WHEN setting up the prefix THEN the system SHALL enable DXVA2 backend for Wine Staging

### Requirement 4

**User Story:** As a user, I want the script to maintain all existing lug-helper wine management features, so that I can manage custom wine runners and troubleshoot issues.

#### Acceptance Criteria

1. WHEN managing wine runners THEN the system SHALL allow installation and deletion of custom wine runners
2. WHEN troubleshooting THEN the system SHALL provide wine prefix configuration access
3. WHEN maintaining the system THEN the system SHALL allow DXVK updates
4. WHEN configuring controllers THEN the system SHALL provide wine controller configuration access
5. WHEN debugging THEN the system SHALL provide wine prefix shell access

### Requirement 5

**User Story:** As a Linux gamer, I want the script to perform system optimization checks, so that my system is properly configured for optimal WoW performance.

#### Acceptance Criteria

1. WHEN running preflight checks THEN the system SHALL verify vm.max_map_count is at least 16777216
2. WHEN checking system limits THEN the system SHALL verify hard open file descriptors limit is at least 524288
3. WHEN checking memory THEN the system SHALL verify at least 16GB RAM is available
4. WHEN checking combined memory THEN the system SHALL verify at least 40GB RAM + swap is available
5. IF any optimization is missing THEN the system SHALL offer to fix the issue with appropriate privileges

### Requirement 6

**User Story:** As a user, I want all references to lug-helper replaced with azeroth-winebar, so that the tool has its own distinct identity and branding.

#### Acceptance Criteria

1. WHEN displaying messages THEN the system SHALL show "Azeroth Winebar" as the application title
2. WHEN creating config directories THEN the system SHALL use "azeroth-winebar" as the subdirectory name
3. WHEN showing help text THEN the system SHALL reference azeroth-winebar instead of lug-helper
4. WHEN creating desktop entries THEN the system SHALL use azeroth-winebar naming conventions
5. WHEN logging or debugging THEN the system SHALL use azeroth-winebar in log messages
6. If there are any named items that refer to Star Citizen, they will be changed to refer to World of Warcraft

### Requirement 7

**User Story:** As a WoW player, I want the script to handle Battle.net-specific configuration, so that the launcher works properly and doesn't interfere with gameplay.

#### Acceptance Criteria

1. WHEN installing Battle.net THEN the system SHALL create proper Battle.net.config with optimized settings
2. WHEN configuring Battle.net THEN the system SHALL disable hardware acceleration to prevent crashes
3. WHEN setting up Battle.net THEN the system SHALL disable streaming and background search features
4. WHEN configuring Battle.net THEN the system SHALL set GameLaunchWindowBehavior to minimize launcher
5. WHEN Battle.net is running THEN the system SHALL exclude helper processes from wine management

### Requirement 8

**User Story:** As a user, I want the script to provide proper launch scripts and desktop integration, so that I can easily start WoW from my desktop environment.

#### Acceptance Criteria

1. WHEN installation completes THEN the system SHALL create a launch script for Battle.net/WoW
2. WHEN creating launch scripts THEN the system SHALL configure proper wine environment variables
3. WHEN setting up desktop integration THEN the system SHALL create .desktop files for easy launching
4. WHEN launching WoW THEN the system SHALL apply shader cache optimizations for both Nvidia and AMD
5. WHEN the game exits THEN the system SHALL properly clean up wine processes