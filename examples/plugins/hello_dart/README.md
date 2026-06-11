# Hello (Dart Demo) — Tilepad plugin

A minimal example plugin that exercises every plugin capability. It uses only the
Dart SDK, so it runs with `dart plugin.dart` and needs no `pub get`.

## What it does

- **`Say Hello` action** — a `name` text field; returns `"<greeting>, <name>!"`.
- **`Pick Favourite Colour` action** — a `select` field whose options come from a
  **dynamic list** the plugin answers at runtime.
- **`greeting` setting** — change the greeting word in the plugin's settings.
- **`clock` live state** — streams the current time once a second; bind a button
  to it (Live Tile → Title) to see it tick on the phone.

## Install

1. On the server, open **Plugins → Open plugins folder**.
2. Copy this `hello_dart` folder into that directory.
3. Press **Rescan**, then toggle the plugin **on**.

Requires the Dart SDK on the server machine (so `dart` is on `PATH`). To avoid
that requirement you can instead compile it:

```bash
dart compile exe plugin.dart -o plugin.exe
```

and change `manifest.json`'s `run` commands to `./plugin.exe` (or `plugin.exe` on
Windows).

See [`docs/plugins/protocol.md`](../../../docs/plugins/protocol.md) for the full
protocol reference.
