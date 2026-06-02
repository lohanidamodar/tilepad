# MarcoDeck Plugin Protocol

MarcoDeck plugins add new actions and live data to the desktop server **without
modifying or recompiling the app** — the same model used by Stream Deck and
Touch Portal.

A plugin is a **folder** containing a `manifest.json` and an **executable**
(written in any language). When enabled, the server launches the executable; the
executable connects back to the server over a local WebSocket and speaks the
JSON protocol below.

Plugins talk **only to the server**. The server forwards live state to phone
clients — your plugin never connects to a phone.

> A complete, copy-pasteable example lives in
> [`examples/plugins/hello_dart/`](../../examples/plugins/hello_dart/).

---

## 1. Install layout

```
<app support>/plugins/
  my-plugin/
    manifest.json        ← required
    plugin.<ext>         ← your executable / script
    icon.png             ← optional
```

Drop the folder into the plugins directory (the **Plugins** screen has an
"Open plugins folder" button), then press **Rescan** and enable it.

---

## 2. `manifest.json`

```jsonc
{
  "id": "com.you.example",        // required, unique, reverse-DNS recommended
  "name": "My Plugin",            // shown in the UI
  "version": "1.0.0",
  "author": "You",
  "apiVersion": 1,                 // protocol version you target (<= host's)

  "run": {                         // required: launch command per OS,
    "windows": "node plugin.js",   // resolved relative to the plugin folder
    "macos":   "node plugin.js",
    "linux":   "node plugin.js"
  },

  "settings": [                    // optional: global plugin configuration
    { "key": "host", "type": "string",   "label": "Host", "default": "localhost" },
    { "key": "pass", "type": "password", "label": "Password" }
  ],

  "actions": [                     // selectable in the button editor
    {
      "id": "do_thing",
      "name": "Do Thing",
      "icon": "icon.png",          // optional
      "fields": [                  // per-action configuration (native-rendered)
        { "key": "mode", "type": "select", "label": "Mode", "optionsFrom": "modes" },
        { "key": "count", "type": "number", "label": "Count", "default": 1 }
      ]
    }
  ],

  "states": [                      // live values you stream (for live tiles)
    { "id": "status", "label": "Status", "type": "string" }
  ],

  "lists": [                       // dynamic option sources for select fields
    { "id": "modes", "label": "Modes" }
  ]
}
```

### Field types

| `type`     | Renders as            | Value         |
|------------|-----------------------|---------------|
| `string`   | text field            | string        |
| `password` | obscured text field   | string        |
| `number`   | numeric field         | number        |
| `bool`     | switch                | boolean       |
| `select`   | dropdown              | string        |

A `select` field uses either static `"options": [{ "value": "...", "label": "..." }]`
or `"optionsFrom": "<listId>"` to fetch options from the plugin at runtime.

The launch command is passed three extra arguments by the server:

```
<your run command> --mdk-port <port> --mdk-plugin-id <id> --mdk-token <token>
```

Connect to `ws://127.0.0.1:<port>` and `register` with the id and token.

---

## 3. Wire protocol

JSON text frames over WebSocket. Every message has a `type`.

### Plugin → Host

| `type`          | Fields                                   | Purpose |
|-----------------|------------------------------------------|---------|
| `register`      | `pluginId`, `token`                      | Identify after connecting. Send first. |
| `actionResult`  | `requestId`, `success`, `output?`, `error?` | Reply to an `invoke`. |
| `listResult`    | `requestId`, `options: [{value,label}]`  | Reply to a `requestList`. |
| `setState`      | `stateId`, `value`                       | Push a live value (title tiles). |
| `setStateImage` | `stateId`, `value?`, `image`             | Push a live icon (icon tiles). |
| `log`           | `level`, `message`                       | Write to the server log. |

### Host → Plugin

| `type`            | Fields                              | Purpose |
|-------------------|-------------------------------------|---------|
| `registered`      | `settings`                          | Ack; current settings values. |
| `invoke`          | `requestId`, `actionId`, `fields`   | Run an action. Reply with `actionResult`. |
| `requestList`     | `requestId`, `listId`, `fields?`    | Get dynamic options. Reply with `listResult`. |
| `settingsUpdated` | `settings`                          | The user changed your settings. |
| `shutdown`        | —                                   | Stop gracefully. |

`requestId` correlates a request with its reply. Requests time out after 10s and
surface to the user as a failed action.

### Typical lifecycle

```
host                         plugin
  │   spawn process ─────────▶ │
  │ ◀──────── register ──────── │   {pluginId, token}
  │ ──────── registered ─────▶ │   {settings}
  │                            │   …streams setState periodically…
  │ ───────── invoke ────────▶ │   {requestId, actionId, fields}
  │ ◀──────── actionResult ─── │   {requestId, success, output}
  │ ──────── requestList ────▶ │   {requestId, listId}
  │ ◀──────── listResult ───── │   {requestId, options}
  │ ───────── shutdown ──────▶ │   (on disable)
```

---

## 4. Live tiles

Declare a state in `states`, then `setState` whenever it changes:

```json
{ "type": "setState", "stateId": "status", "value": "Recording" }
```

In the button editor, a user binds a button to your state ("Live Tile" section)
so the phone shows the live value as the button's **title**, or — with
`setStateImage` and an icon-mode binding — swaps the button's **icon**. On
connect the server replays the latest snapshot so tiles render immediately.

> **Icon-mode payloads:** for an *icon* binding, send `image` as a numeric icon
> code point string (the same format MarcoDeck uses for button icons), e.g.
> `{ "type": "setStateImage", "stateId": "mic", "image": "61234" }`. Named icons
> and data-URI images are not resolved yet. *Title* bindings just use `value`.

---

## 5. Security

Plugins are programs you choose to install and enable, exactly like Stream Deck /
Touch Portal. The plugin WebSocket is bound to `127.0.0.1` only and each plugin
is admitted with a one-time token. Only install plugins you trust.
