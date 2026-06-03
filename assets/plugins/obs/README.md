# OBS Studio plugin

Control [OBS Studio](https://obsproject.com/) from MarcoDeck: switch scenes,
toggle recording and streaming, and show the current scene + record/stream
status as live tiles.

It speaks **obs-websocket v5** (built into OBS 28+) and the MarcoDeck plugin
protocol. Pure Dart SDK — no `pub get`.

## Setup

This plugin is **bundled with MarcoDeck** — it's seeded into your plugins folder
on first run and already appears in the **Plugins** list. Just:

1. In OBS: **Tools → WebSocket Server Settings → Enable WebSocket server**.
   Note the **Port** (default `4455`) and, if set, the **Password**.
2. In MarcoDeck **Plugins**, enable **OBS Studio** and set the **Password**
   (and Host/Port if not the defaults) in its settings.

Release builds launch a pre-compiled native binary (`obs-plugin.exe` on
Windows), so no Dart SDK is required on the target machine. On macOS/Linux the
plugin runs from source via the Dart SDK until native binaries are published —
build one with `dart run tool/build_plugins.dart` on that platform.

## Actions

| Action | What it does |
|--------|--------------|
| Switch Scene | Set the current program scene (scene list is fetched live) |
| Toggle / Start / Stop Recording | Control recording |
| Toggle / Start / Stop Streaming | Control streaming |

## Live tiles

Bind a button's **Live Tile** to one of:

| State | Shows |
|-------|-------|
| `scene` | current program scene name |
| `recording` | `● REC` / `Idle` |
| `streaming` | `● LIVE` / `Offline` |
| `obs` | `Connected` / `Disconnected` |

The plugin reconnects automatically if OBS isn't running yet or restarts.

## Protocol logic

The pure protocol helpers (v5 auth, message builders, event→state mapping) live
in [`obs_protocol.dart`](./obs_protocol.dart) and are unit-tested in
`test/plugins/obs_protocol_test.dart` (SHA-256 against NIST vectors, the
documented auth composition, and event mapping). `plugin.dart` is the
`dart:io` WebSocket glue.
