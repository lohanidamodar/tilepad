# Changelog

All notable changes to the MarcoDeck project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-06-03

### Added

#### 🎛️ Buttons, tiles & presets
- **Preset catalog**: Drop-in, cross-platform buttons grouped into Media, System, Apps, Web, Window, Clipboard and Navigation
- **New action types**: open URL, media/transport keys, and client-side page navigation
- **Live tiles**: Built-in system metrics (CPU, RAM, disk, uptime, clock, battery, network) plus any plugin-streamed state
- **Full-page add-button picker**: Searchable, category-filtered grid with a "Live tiles" filter and **multi-select**
- **Run on server**: Test a button's actions on the desktop with no client connected
- **Reorderable pages** and a redesigned, searchable **Manage Buttons** grid

#### 🧩 Plugins
- **Bundled OBS Studio plugin** (obs-websocket v5): scene switching, recording/streaming toggles, live status tiles, and a Test Connection button
- **First-party plugins are bundled and shipped as native binaries**, seeded into the plugins folder on first run (no Dart SDK required on the target)
- **Plugin presets**: plugins can contribute ready-made buttons that appear in the picker while enabled

#### 🖥️ Server
- **Client management**: disconnect a connected client and block/unblock its IP (persisted)

#### 📦 Release & packaging
- **Tag-triggered releases**: pushing a `vX.Y.Z` tag builds and publishes the Android client, Windows and Linux servers
- **Windows installer** built with Inno Setup, attached to each release

### Fixed
- **Reconnection reliability**: real socket verification, handshake re-send on recovery, and bounded close so a dropped server reconnects cleanly without wedging the client
- Dark-mode contrast for tooltips/snackbars and deck-tile readability

## [1.1.0] - 2024-09-01

### Added

#### 🎨 UI/UX Enhancements
- **Material Design 3 Theming**: Comprehensive theming system with consistent design language
- **Enhanced Button Grid**: Smooth animations with scaling effects and elevation changes
- **Improved Splash Screen**: Animated logo with progress tracking and smooth transitions
- **Modern Server Interface**: Gradient backgrounds, animated status indicators, and enhanced cards
- **Visual Feedback**: Haptic feedback integration throughout the interface
- **Enhanced Settings Screen**: Completely redesigned with organized sections and better navigation

#### ♿ Accessibility Features
- **High Contrast Themes**: Enhanced visibility options for users with visual impairments
- **Text Scaling Support**: Adjustable text size from 80% to 200%
- **Reduced Motion Options**: Animation controls for motion-sensitive users
- **Screen Reader Support**: Full semantic labeling and announcements
- **Accessible Button Components**: Proper focus management and keyboard navigation
- **Haptic Feedback Levels**: Multiple intensity options for different interaction types

#### 🌐 Network Improvements
- **Advanced Reconnection Logic**: Exponential backoff with jitter for better reliability
- **Connection Health Monitoring**: Continuous ping/pong health checks
- **Adaptive Retry System**: Smart retry mechanisms with configurable limits
- **Connection Verification**: Timeout-based establishment verification
- **Enhanced Error Handling**: Better error reporting and recovery mechanisms
- **Network Quality Indicators**: Real-time connection status throughout the interface

#### 🛠️ Development Tools
- **Comprehensive Logging System**: Multi-level logging with component-specific output
- **Build Verification Script**: Automated cross-platform build testing
- **Accessibility Utilities**: Reusable components for accessible UI development
- **Enhanced Documentation**: Detailed README and code documentation

### Changed

#### Server Interface
- **Connection Display**: Enhanced connection info with modern card layouts
- **Client Management**: Improved connected clients view with status badges and connection duration
- **Button Management**: Better visual hierarchy and organization
- **Status Indicators**: Animated status displays with real-time updates

#### Client Interface
- **Button Interactions**: Enhanced touch feedback and visual states
- **Connection Handling**: Improved reconnection UX with user feedback
- **Navigation**: Better accessibility and keyboard navigation support
- **Settings Organization**: Reorganized settings with logical grouping and improved controls

#### Network Layer
- **WebSocket Implementation**: Complete rewrite with enhanced reliability features
- **Message Protocol**: Improved error handling and timeout management
- **Connection Management**: Better state tracking and recovery mechanisms
- **Platform Support**: Enhanced web and mobile platform compatibility

### Fixed

#### Stability Improvements
- **Connection Reliability**: Fixed intermittent connection drops and reconnection issues
- **Memory Management**: Improved resource cleanup and disposal patterns
- **Error Handling**: Better error recovery and user feedback mechanisms
- **Platform Compatibility**: Fixed platform-specific networking issues

#### UI/UX Fixes
- **Animation Performance**: Optimized animations for better performance
- **Theme Consistency**: Fixed theme application across all components
- **Accessibility Issues**: Resolved focus management and screen reader compatibility
- **Responsive Design**: Fixed layout issues on different screen sizes

### Technical Details

#### Dependencies Updated
- Flutter SDK compatibility: >=3.7.2
- Enhanced Material Design 3 support
- Improved web platform compatibility
- Better desktop platform integration

#### Architecture Improvements
- Modular component organization
- Enhanced provider pattern implementation
- Better separation of concerns
- Improved error boundary handling

#### Performance Optimizations
- Reduced animation overhead for accessibility
- Optimized network message handling
- Better memory usage patterns
- Improved rendering performance

## [1.0.0] - Initial Release

### Added
- Basic client-server architecture
- WebSocket communication
- Button management system
- Cross-platform support
- Multi-page button organization
- Command execution framework
- System tray integration
- Basic theming support

---

## Development Notes

### Upgrade Instructions
When upgrading from version 1.0.0:

1. **Clean Installation Recommended**: `flutter clean && flutter pub get`
2. **New Settings**: Review new accessibility and display settings
3. **Network Configuration**: Connection settings remain compatible
4. **Button Configuration**: All existing buttons are preserved

### Breaking Changes
- None in this release - fully backward compatible

### Migration Guide
No migration required for existing users. All data and configurations are preserved.

### Known Issues
- Build verification script requires Flutter SDK in PATH
- iOS builds require Xcode on macOS
- Some advanced accessibility features may require device restart to take full effect

### Upcoming Features (Roadmap)
- [ ] Server discovery via network scanning
- [ ] Button import/export functionality
- [ ] Advanced macro scripting support
- [ ] Plugin system for custom actions
- [ ] Cloud synchronization options
- [ ] Multi-language support

---

For more details on any changes, see the [commit history](https://github.com/lohanidamodar/macro-deck-updated/commits/main) or [GitHub releases](https://github.com/lohanidamodar/macro-deck-updated/releases).