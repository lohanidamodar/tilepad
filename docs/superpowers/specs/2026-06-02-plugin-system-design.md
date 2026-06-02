# MarcoDeck Plugin System — Design

**Date:** 2026-06-02
**Status:** Approved (brainstorming)
**Branch:** `worktree-plugin-system`

## Goal

Let third-party developers add new capabilities to MarcoDeck **without modifying or
recompiling the app**. Plugins are pluggable, can be enabled/disabled at runtime, and
support dynamic, two-way capabilities (configurable actions, dynamic option lists,
plugin settings, and live state pushed to the phone client).

This mirrors how Stream Deck and Touch Portal work: a plugin is an **out-of-process
executable** (any language) that talks to the app over a socket using a documented JSON
protocol, declared via a manifest. We do **not** embed a scripting language.

### Why out-of-process (and not embedded Dart/Lua/JS)

- Flutter **release** builds are AOT-compiled; there is no Dart VM/kernel compiler in the
  binary, so arbitrary `.dart` files cannot be loaded at runtime (`Isolate.spawnUri` on
  source does not work in release).
- `dart_eval` only supports a Dart subset and requires hand-written bindings for every
  capability — high effort, fragile.
- Embedding Lua/JS would force one language + a sandbox we must maintain, and is *less*
  like the premium apps, not more.
- Stream Deck and Touch Portal both use out-of-process executables + manifest + socket.
  This is language-agnostic, recompile-free, crash-isolated, and fits MarcoDeck's existing
  JSON-over-WebSocket architecture.

## Scope (v1)

All five dynamic capabilities are in scope for v1:

1. **Configurable actions** — action settings fields rendered natively by the server editor.
2. **Dynamic choice lists** — dropdown options supplied by the plugin at runtime.
3. **Plugin settings** — global per-plugin config (e.g. API keys).
4. **Live button state/title** — plugin streams values; phone shows live text/value.
5. **Live button icon swaps** — plugin-driven icon changes by state.

Plugins talk **only to the server**. The server keeps a live state store and forwards
updates to phone clients over the existing client WebSocket. The plugin never talks to the
phone directly.

**Not in scope for v1:** an official maintained SDK library (we ship the protocol spec + a
minimal Dart sample plugin only), a marketplace, code signing/sandboxing (we match Stream
Deck/Touch Portal: plugins are executables the user chooses to trust).

## Architecture

```
┌─────────────────────── Desktop Server ───────────────────────┐
│  PluginRegistry — discovers/installs plugins, reads manifests │
│        │           tracks enabled/disabled (persisted)        │
│        ▼                                                       │
│  PluginHost ──── spawns & supervises plugin processes         │
│    │   │         owns the plugin WebSocket (default :8091)    │
│    │   │         routes actions, dynamic lists, settings      │
│    │   ▼                                                       │
│    │  StateStore — latest value per (pluginId, stateId)       │
│    ▼                                                          │
│  CommandExecutor — ActionType.plugin → PluginHost.invoke()    │
│                                                               │
│  Client WebSocket ◀── forwards state updates ──┐              │
└─────────────────────────────────────────────────┼────────────┘
        ▲ phone renders buttons + LIVE TILES       │
        └───────────────────────────────────────────┘

  Plugin process (any language) ──WS──▶ PluginHost
  e.g. dart plugin.dart / node plugin.js / python plugin.py
```

New module: `lib/src/server/plugins/`

| File | Responsibility |
|------|----------------|
| `plugin_manifest.dart` | Parse/validate `manifest.json` into typed models. |
| `plugin_registry.dart` | Discover plugins on disk, install from zip, persist enabled/disabled + settings. |
| `plugin_process.dart` | Wrap one OS process: spawn with args, supervise, restart on crash, stop. |
| `plugin_host.dart` | Own the plugin WebSocket, handshake/register plugins, route protocol messages, expose `invoke`, `requestList`, `pushSettings`. |
| `state_store.dart` | In-memory latest value per `(pluginId, stateId)`; change stream. |
| `plugin_protocol.dart` | Message type constants + encode/decode helpers for the plugin protocol. |

`CommandExecutor` gains one branch (route `ActionType.plugin` to the host). `MarcoServer`
wires the host, forwards state updates to clients, and exposes registry operations to the UI.

### Process lifecycle (Stream Deck style)

- Server starts the plugin WebSocket on a configurable port (default `8091`, bound to
  `127.0.0.1` only).
- For each **enabled** plugin, the host spawns the process from `manifest.run[platform]`,
  passing args: `--mdk-port <port> --mdk-plugin-id <uuid> --mdk-token <oneTimeToken>`.
- The plugin connects back and sends `register` with its id + token. The host validates the
  token, marks it connected, and replies `registered`.
- **Enable** = spawn + supervise (restart with backoff on unexpected exit). **Disable** =
  send `shutdown`, then terminate the process; hide its actions/states.
- Crash isolation: a plugin crash never takes down the server; the host marks it
  disconnected and restarts (bounded).

## Plugin package & manifest (developer contract)

A plugin is a folder under the server's plugins directory
(`<app support dir>/plugins/<plugin-id>/`). The UI offers "Import plugin (.zip)" which
unzips into that directory.

```
my-plugin/
  manifest.json
  plugin.dart (or plugin.js / plugin.py / ./plugin.exe)
  icon.png
  assets/…
```

`manifest.json`:

```jsonc
{
  "id": "com.you.obs",            // reverse-DNS unique id
  "name": "OBS Control",
  "version": "1.0.0",
  "author": "You",
  "apiVersion": 1,                 // protocol version the plugin targets
  "run": {                         // per-OS launch command, relative to plugin dir
    "windows": "node plugin.js",
    "macos":   "node plugin.js",
    "linux":   "node plugin.js"
  },
  "settings": [                    // capability 3: global plugin config
    { "key": "host", "type": "string", "label": "OBS host", "default": "localhost" },
    { "key": "password", "type": "password", "label": "Password" }
  ],
  "actions": [
    {
      "id": "switch_scene",
      "name": "Switch Scene",
      "icon": "icon.png",
      "fields": [                  // capability 1: native-rendered action settings
        { "key": "scene", "type": "select", "label": "Scene", "optionsFrom": "scenes" }
      ]
    },
    { "id": "toggle_mute", "name": "Toggle Mic Mute" }
  ],
  "states": [                      // capability 4/5: live values the plugin streams
    { "id": "current_scene", "label": "Current Scene", "type": "string" },
    { "id": "mic_muted",     "label": "Mic Muted",     "type": "bool" }
  ],
  "lists": [                       // capability 2: dynamic option sources
    { "id": "scenes", "label": "Scenes" }
  ]
}
```

**Field types (v1):** `string`, `password`, `number`, `bool`, `select` (static `options`
or dynamic `optionsFrom: <listId>`). These render natively in the server editor — no HTML
property inspector.

**Validation:** required keys (`id`, `name`, `version`, `run` for current OS); unknown
keys ignored (forward-compat); duplicate ids rejected; `apiVersion` must be ≤ host version.

## Wire protocol (plugin ↔ host)

JSON text frames over WebSocket. Every message: `{ "type": <string>, ... }`. Mirrors the
existing `Message` style for consistency.

**Plugin → Host**

| type | payload | purpose |
|------|---------|---------|
| `register` | `pluginId`, `token` | Identify after connecting. |
| `actionResult` | `requestId`, `success`, `output?`, `error?` | Result of an invoked action. |
| `listResult` | `requestId`, `options: [{value,label}]` | Reply to a dynamic-list request. |
| `setState` | `stateId`, `value` | Push a live state value (capability 4/5). |
| `setStateImage` | `stateId`, `image` (data/icon name) | Push a live icon (capability 5). |
| `log` | `level`, `message` | Diagnostic logging surfaced in server logs. |

**Host → Plugin**

| type | payload | purpose |
|------|---------|---------|
| `registered` | `settings` (current values) | Ack registration; hand over saved settings. |
| `invoke` | `requestId`, `actionId`, `fields` (settings) | Run an action. |
| `requestList` | `requestId`, `listId`, `fields?` | Ask for dynamic options. |
| `settingsUpdated` | `settings` | User changed plugin settings. |
| `shutdown` | — | Graceful stop requested. |

`requestId` is a host-generated correlation id; results time out (default 10s) and surface
as a failed `CommandResult`.

### Client-facing additions (server → phone, existing WebSocket)

New `MessageType`s:

- `stateUpdate` — payload `{ pluginId, stateId, value, image? }`. Server forwards on every
  `setState`/`setStateImage`. On client connect, the server replays the current StateStore
  snapshot so tiles render immediately.

Buttons gain an optional **state binding** so a tile shows live data (see model below).

## Data model changes

`ButtonAction` (in `lib/src/models/button.dart`):

- Add `ActionType.plugin`.
- Add `String pluginId` and `String pluginActionId`.
- Add `Map<String, dynamic> settings` (generic field values for plugin actions).
  Existing `command`/`key`/`modifiers` remain for built-in actions (back-compat preserved;
  `fromJson`/`toJson` extended additively).

`Button`:

- Add optional `StateBinding? stateBinding` → `{ pluginId, stateId, mode: title|icon }`.
  When present, the client renders a live tile bound to that state. Null = normal button.
  Serialized additively; old buttons deserialize unchanged.

`CommandExecutor.executeAction`: add `case ActionType.plugin:` → call
`PluginHost.invoke(pluginId, actionId, settings)` and map the returned `actionResult` to a
`CommandResult`. The host is injected (constructor) so the executor stays testable with a
fake host.

## Management UI (server)

- **Plugins screen**: list installed plugins (name, version, author, status:
  enabled/connected/error), with Enable/Disable toggle, Import (.zip), Remove, and a
  Settings dialog rendered from `manifest.settings`.
- **Button editor**: when a plugin action is chosen, render its `fields` natively; `select`
  fields with `optionsFrom` fetch options live via the host. Add an optional "Live tile"
  section to bind the button to a plugin state.

## Security note (v1)

Plugins are arbitrary executables the user installs, exactly like Stream Deck/Touch Portal.
v1 has no sandbox. Mitigations: plugin WebSocket bound to `127.0.0.1` only; per-plugin
one-time registration token; install/enable requires explicit user action with a clear
"this runs a program on your computer" confirmation. Signing/marketplace is future work.

## Testing strategy

- **Unit (pure Dart, `flutter test`)**: manifest parse/validate; registry enable/disable +
  persistence; protocol encode/decode; StateStore; `CommandExecutor` plugin routing with a
  fake host; `ButtonAction`/`Button` JSON round-trips (incl. back-compat with legacy JSON).
- **Integration**: `PluginHost` against a real in-process fake plugin (a Dart WebSocket
  client) — register → invoke → actionResult; requestList → listResult; setState →
  StateStore + client forward.
- **Widget**: existing boot test stays green; add a client live-tile render test.
- **Device**: run server on Windows desktop + client, install the demo Dart plugin, verify
  action execution, dynamic list, settings, and a live tile updating on the phone.

## Deliverables

- `lib/src/server/plugins/` module + model/executor/server wiring + management UI.
- Client state store + live-tile rendering.
- **Demo plugin in Dart** under `examples/plugins/hello_dart/` exercising an action, a
  dynamic list, and a live state.
- Docs: `docs/plugins/protocol.md` (wire protocol + manifest reference) and a short authoring
  guide referencing the demo.

## Build order (incremental, each independently testable)

1. Manifest models + registry (+ tests).
2. Protocol + host + process supervision + StateStore (+ tests with fake plugin).
3. Model changes + executor routing + server wiring + client `stateUpdate` forwarding (+ tests).
4. Server management UI + action field rendering + dynamic lists.
5. Client live-tile rendering.
6. Demo Dart plugin + docs.
7. Push, PR, analyzer/tests green, device test + fixes.
