# Changelog

All notable changes to the Tilepad project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1] - 2026-06-11

### Added
- **Launch at startup**: a server setting (⋮ → Launch at startup) registers Tilepad with the OS so the server starts when you log in — a registry `Run` entry on Windows, a LaunchAgent on macOS, an XDG autostart entry on Linux. The OS entry is the source of truth, so the checkbox always shows what will actually happen at login

### Changed
- **Releases are cut from `main`**: merging a `pubspec.yaml` version bump now tags, builds and publishes the GitHub release automatically — no more `release/*` trigger branches

## [1.4.0] - 2026-06-11

### Changed
- **The project is now Tilepad** (formerly MarcoDeck): app names, the Dart package, platform application ids (`dev.appwriters.tilepad`), the Windows installer, release artifact names (`Tilepad-*`) and the bundled OBS plugin id (`com.tilepad.obs`) are all renamed. Because the application ids changed, configuration and preferences start fresh after upgrading — **export your profile from the old version first** (⋮ → Export profile) and import it in Tilepad

### Added
- **Active Window live tile**: a new system state shows the focused window's title on a tile, on all three platforms (native Win32 on Windows; System Events on macOS — same Accessibility permission as keystrokes; `xdotool` on Linux/X11). Offered as a preset next to the other system tiles

### Fixed
- **Preset reliability across Linux distros**: Screenshot, Terminal and Text Editor presets now try the common tools in turn (`flameshot`/`gnome-screenshot`/`spectacle`, `x-terminal-emulator`/`gnome-terminal`/`konsole`, `gedit`/`gnome-text-editor`/`kate`) instead of assuming one distro's default
- Live states no longer re-broadcast unchanged values to every client on each 2-second sample (clock, metrics, active window)

## [1.3.1] - 2026-06-11

### Fixed
- **Prompt text was typed twice (commands ran twice) after a server restart**: every `start()` added another listener on the client-message stream without cancelling the previous one, so each restart multiplied how many times a press was handled. Subscriptions are now cancelled and re-created per start, with a restart regression test that counts exactly one result per press

## [1.3.0] - 2026-06-11

### Added

#### 🔐 Security
- **PIN pairing**: optionally require devices to enter a 6-digit PIN (shown on the server under ⋮ → Security) the first time they connect. Unpaired sockets can't run actions or receive page/state broadcasts; the client prompts for the PIN, stores it with the saved server, and reconnects

#### 🎛️ Buttons & actions
- **Toggle (two-state) buttons**: a button can carry a second face (name, icon, color and its own action set) and alternates faces on each press — e.g. Mute/Unmute, Start/Stop recording. The active face is tracked on the server, persisted across restarts, and synced live to every connected device
- **Hold (long-press) actions**: a button can run a different action set when held on the device instead of tapped, with distinct haptic feedback
- **Delay action**: pause a multi-action sequence for up to 60 s (e.g. launch an app, wait, then send it keystrokes)
- **Navigate to a specific page**: page-navigation buttons can now jump straight to a named page, not just next/prev/first/last

#### 🖥️ Server
- **Profile export/import**: back up the whole button/page configuration to a JSON file and restore or move it to another machine (⋮ menu on the dashboard). Importing keeps a safety copy of the replaced configuration as `pages.json.bak`
- **Duplicate button**: copy any library button (including its toggle face and hold actions) from the Manage Buttons grid
- **27 new catalog presets**: Mute is now a real toggle (flips to a red "Unmute" face), plus Task Manager, Settings, Code Editor, Spotify, Downloads, Twitch, Reddit, ChatGPT, Switch App, Minimize, Select All, Undo, Redo, First/Last Page navigation, a **Browser** category (New/Close/Reopen Tab, Refresh, Address Bar) and a **Meetings** category (Zoom/Teams/Meet mute & camera toggles)
- **Live tray menu**: the system tray now shows the server state, address and connected-device count, and offers Start/Stop/Restart, Copy server address and Open Tilepad — control the server without opening the window. Exiting from the tray stops the server cleanly first

#### 📱 Client
- **Fullscreen mode**: hide the status/navigation bars so the deck uses the whole screen (Settings → Display)
- **Screen orientation setting**: portrait, landscape or auto-rotate — landscape suits tablets mounted sideways

### Changed

#### 🎨 UI polish
- **One quiet section style everywhere**: the button and action editors now use a shared compact `SectionCard` (hairline border, small accent icon, inline header controls) instead of the old solid accent-filled headers — less visual noise, same minimal feel
- **Compact action lists**: dense rows with a small type icon, one-line summaries, tap-to-edit, and a single delete affordance
- **Unified color swatches**: the button color and toggled-on color pickers share one swatch row style
- The toggled-on face's actions and hold actions are flat sibling sections — no more cards nested inside cards
- Uniform app-bar actions on the server dashboard and `Save` buttons across editors

### Fixed

#### 🧭 Cross-platform correctness (audit of every preset & action path)
- **macOS media transport now actually works**: synthesising F7–F9 key codes never triggered the hardware media functions; Play/Pause/Next/Previous/Stop now control Music and Spotify directly
- **macOS Lock Screen** uses the real Ctrl⌘Q lock (display-sleep only locked when "require password after sleep" was on); **Restart/Shutdown** no longer call `sudo` (a macro press can't answer a password prompt) — macOS asks System Events, Linux goes through `systemctl`/logind
- **Window presets are now per-desktop**: Win-key snapping on Windows, Super-key (GNOME) on Linux with the correct Minimize (Super+H), and Cmd shortcuts + Mission Control on macOS; Select Window only appears on Windows where it works
- Linux "Web Browser" preset opened a literal `https://`; macOS "Settings" now opens on both pre- and post-Ventura names
- **OBS plugin no longer needs the Dart SDK on Linux**: releases compile and bundle a standalone binary (the manifest prefers it, and source checkouts automatically fall back to `dart plugin.dart`)

#### 🔐 PIN pairing follow-ups (from device testing)
- **Auto-reconnect after a server restart works again**: the deliberate-close fix accidentally cleared the service's remembered address inside `connect()` itself, silently disabling all socket-level auto-reconnect; covered by new loopback reconnect tests (restart ⇒ reconnects, deliberate close ⇒ stays closed)
- The PIN prompt no longer resets while typing: a pairing rejection now fully closes the transport (the service's auto-reconnect kept reconnecting and getting dropped), unauthorized pings get a normal `pong` so health checks stay calm, repeated rejections are de-duplicated, and the dialog is single-instance with its text controller owned by the dialog (fixes a "controller used after dispose" crash and a render overflow)
- The tray menu no longer flickers: it only rebuilds when its content actually changes

- The action editor now has proper forms for **Open URL**, **Media Key** and **Navigate Page** actions; previously selecting these types saved an action with an empty target that did nothing
- Unknown message types received from a newer peer no longer crash the message decode loop
- Removed the unused `server_screen_new.dart` dead code

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

For more details on any changes, see the [commit history](https://github.com/lohanidamodar/tilepad/commits/main) or [GitHub releases](https://github.com/lohanidamodar/tilepad/releases).