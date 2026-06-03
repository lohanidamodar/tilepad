# Preset System-Info Live Tiles

**Date:** 2026-06-02 · **Branch:** `worktree-system-info`

## Goal

Built-in **preset live tiles** showing live system metrics (CPU %, RAM, Disk,
Uptime, Hostname) — no plugin/SDK required. Reuses the existing live-tile
pipeline (StateStore → server → client) so there is no new protocol.

## Architecture

- **Shared `StateStore`** owned by `MarcoServer` (was owned by `PluginHost`).
  It is passed to `PluginHost(stateStore: …)` and to a new
  `SystemInfoService`, and the server forwards its `changes` to clients. So
  system tiles work even if the plugin subsystem fails.
- **`SystemInfoService`** (in-process, no external process): a `Timer` samples
  metrics every ~2s and writes them to the store under the reserved source id
  **`system`** (states `cpu`, `ram`, `disk`, `uptime`, `host`). Cross-platform
  with graceful fallback (a metric that can't be read is skipped).
  - Linux: `/proc/stat` (CPU), `/proc/meminfo` (RAM), `/proc/uptime`, `df`.
  - Windows: PowerShell/CIM (`Win32_Processor`, `Win32_OperatingSystem`,
    `Win32_LogicalDisk`).
  - macOS: `top -l1`, `sysctl`, `vm_stat`, `df`.
  - Hostname: `Platform.localHostname`.
  - **Parsers are pure functions** (parse `/proc/stat`, `meminfo`, `df`, CIM
    output) → unit-tested with sample strings.
- **`systemStates`** — a const list (`id`, `label`, `icon`) shared by the
  service (what to publish) and the UI (what to offer / preset).

## UI

- **Live-Tile picker**: the button editor lists the `system` states as a
  built-in "System" source alongside plugins (so any button can bind to e.g.
  `system/cpu`).
- **Preset buttons**: the button library picker gains a "System info" presets
  section (CPU / RAM / Disk / Uptime / Host) — picking one creates a library
  button pre-bound to that system state (name + icon) and places it.
- **Live-tile rendering** (client): in title mode, show the button **name**
  (small, muted) above the live **value** (prominent), so a tile reads "CPU /
  42%". Falls back to just the name before the first value arrives. (Improves
  plugin live tiles too.)

## Testing

- Unit (TDD): the pure parsers (`/proc/stat` delta → %, `meminfo` → used/total,
  `df` → %, CIM key=value); `SystemInfoService` publishes states into a fake
  StateStore; `systemStates` wired into the picker.
- `flutter analyze` clean; `flutter build windows` OK.
- Device: Windows server shows live CPU/RAM/Disk/Uptime tiles on the phone.

## Build order
1. `system_info.dart`: states const + pure parsers + `SystemInfoService`.
2. Shared StateStore in `MarcoServer`; start the service; forward + snapshot.
3. Live-Tile picker includes system states; preset buttons in the library.
4. Client live-tile name+value rendering.
5. Verify + device test + PR.
