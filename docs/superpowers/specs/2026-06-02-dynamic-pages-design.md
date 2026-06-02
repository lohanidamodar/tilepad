# Dynamic Pages — Button Library + Spanning Grid

**Date:** 2026-06-02
**Status:** Approved direction (autonomous build)
**Branch:** `worktree-dynamic-pages`

## Goal

Make pages dynamic: a **shared button library** + pages composed of **tiles** that
place a button on a **spanning grid** with per-tile size (colSpan × rowSpan), and
let the user **drag to rearrange** and resize. The client renders the spanning
layout responsively. **No backward compatibility** — this is a clean model.

## Model (clean, no legacy)

- **Button** (library definition): `id`, `name`, `iconName`, `color`,
  `List<ButtonAction> actions`, `StateBinding? stateBinding`. Addressed by id;
  reusable across pages. (The legacy `ButtonType` getters/converters on `Button`
  are removed.)
- **Tile** (placement on a page): `id`, `buttonId`, `int colSpan` (default 1),
  `int rowSpan` (default 1).
- **Page**: `id`, `name`, `int order`, `int columns` (grid width, default 4),
  `List<Tile> tiles` (flow order).

Deleting a library button removes its tiles from every page.

## Persistence (server)

`ButtonManager` stores the library + pages and persists a single JSON config:
```jsonc
{
  "buttons": [ { id, name, iconName, color, actions, stateBinding? } ],
  "pages":   [ { id, name, order, columns, tiles: [ { id, buttonId, colSpan, rowSpan } ] } ]
}
```

## Protocol (server → client)

Pages are sent **denormalized** so the client renders directly without a separate
library sync. `pagesResponse` payload = pages where each tile embeds the resolved
button:
```jsonc
[ { id, name, order, columns,
    tiles: [ { id, colSpan, rowSpan, button: { id, name, iconName, color, actions, stateBinding? } } ] } ]
```
On press the client sends the **button id** (`tile.button.id`); the server runs
the library button. `stateUpdate` (live tiles) is unchanged — keyed by
plugin/state, applied to any tile whose button binds it.

## Client rendering

`button_grid` switches to `flutter_staggered_grid_view`:
`StaggeredGrid.count(crossAxisCount: page.columns, children: tiles.map((t) =>
StaggeredGridTile.count(crossAxisCellCount: t.colSpan, mainAxisCellCount:
t.rowSpan, child: <button tile>)))`. Cells are sized by the grid to fill width,
so spans scale across phone sizes. Live tiles, prompts and presses work per tile.

## Server UI

Two surfaces, matching the agreed two-step authoring:

1. **Manage Buttons** — the library: a grid/list of buttons with add / edit /
   delete. Reuses the existing button editor for the definition (name, icon,
   color, actions, live-tile binding).
2. **Manage Page** (composer) — a spanning grid of the page's tiles:
   - **Drag to reorder** tiles on the grid (custom `Draggable`/`DragTarget`
     over the staggered grid; drop reorders the flow list).
   - **Resize** a tile (1×1 / 2×1 / 1×2 / 2×2 control per tile).
   - **Add** via a picker = existing library buttons **+ "Add new button"**
     (opens the button editor, creates it in the library, then places it).
   - **Remove** a tile from the page (button stays in the library).
   - Set the page's **columns**.

`MarcoServer` exposes library + composition operations and broadcasts the
denormalized pages on any change (existing `_broadcastPages`).

## Testing

- Unit (TDD): `Button`/`Tile`/`Page` JSON round-trips; `ButtonManager` library
  CRUD; tile add/remove/reorder/resize; deleting a button purges its tiles;
  denormalization for the wire; persistence round-trip.
- Client: `Page.fromJson` with embedded tile buttons; staggered render smoke.
- `flutter analyze` clean; `flutter build windows` OK.
- Device: server compose (add/drag/resize) → client renders the spanning layout
  live; press a tile; live tile still ticks.

## Build order

1. Model: `Button` (library), `Tile`, `Page` (columns + tiles) — TDD.
2. `ButtonManager`: library + pages + tile ops + persistence — TDD.
3. `MarcoServer`: library/composition API + denormalized broadcast — TDD where
   pure.
4. Client: `Page`/`Tile` model + staggered grid rendering.
5. Server UI: Manage Buttons + Manage Page composer (drag/resize/picker).
6. Device test + PR.
