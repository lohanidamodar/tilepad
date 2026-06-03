import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picons/picons.dart';

import '../models/button.dart';
import 'button_presets.dart';
import 'system_info.dart';

/// Manages the server's button library and the pages that place those buttons
/// on a spanning grid.
///
/// Buttons live in a single [library]; each page holds [Tile]s that reference a
/// library button (by id) with a per-placement size. Tiles in memory hold the
/// resolved [Button] object, so editing a library button is reflected on every
/// page. Storage is normalised (tiles persist `buttonId` + spans); the wire and
/// UI use the resolved (denormalised) [Page]/[Tile] objects.
class ButtonManager {
  final List<Button> _library = [];
  List<Page> _pages = [];
  String? _configPath;

  /// The button library.
  List<Button> get buttons => List.unmodifiable(_library);

  /// All pages with resolved tiles.
  List<Page> get pages => List.unmodifiable(_pages);

  Future<void> initialize() async {
    await _loadConfig();
    if (_library.isEmpty && _pages.isEmpty) {
      _createDefaults();
      await saveConfig();
    } else if (dedupeSystemButtons()) {
      await saveConfig();
    }
  }

  /// Collapses duplicate system-metric library buttons that share the same
  /// live-state binding into a single canonical button, re-pointing any tiles
  /// that placed a duplicate. Earlier builds added a fresh library button on
  /// every system-preset placement, so saved configs can accumulate several
  /// identical "System Monitor"/"CPU"/... entries. Returns whether anything
  /// changed.
  bool dedupeSystemButtons() {
    final canonicalByState = <String, Button>{};
    final remap = <String, String>{}; // duplicate id -> canonical id
    for (final b in _library) {
      final binding = b.stateBinding;
      if (binding == null || binding.pluginId != systemSourceId) continue;
      final canonical = canonicalByState[binding.stateId];
      if (canonical == null) {
        canonicalByState[binding.stateId] = b;
      } else {
        remap[b.id] = canonical.id;
      }
    }
    if (remap.isEmpty) return false;

    // Re-point tiles that referenced a duplicate to the canonical button
    // (before removing the duplicates so the canonical is still resolvable).
    for (final page in _pages) {
      for (var i = 0; i < page.tiles.length; i++) {
        final tile = page.tiles[i];
        final canonicalId = remap[tile.buttonId];
        if (canonicalId == null) continue;
        final canonical = getButton(canonicalId);
        if (canonical != null) {
          page.tiles[i] = Tile(
            id: tile.id,
            button: canonical,
            colSpan: tile.colSpan,
            rowSpan: tile.rowSpan,
          );
        }
      }
    }

    _library.removeWhere((b) => remap.containsKey(b.id));
    return true;
  }

  // --- Persistence -----------------------------------------------------------

  Future<void> _loadConfig() async {
    try {
      final directory = await _getConfigDirectory();
      final file = File('${directory.path}/pages.json');
      _configPath = file.path;
      if (!await file.exists()) return;

      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) return;

      _library.clear();
      for (final b in (data['buttons'] as List<dynamic>? ?? const [])) {
        _library.add(Button.fromJson(b as Map<String, dynamic>));
      }
      _pages = [];
      for (final p in (data['pages'] as List<dynamic>? ?? const [])) {
        final page = _pageFromStorage(p as Map<String, dynamic>);
        if (page != null) _pages.add(page);
      }
    } catch (e) {
      debugPrint('Error loading configuration: $e');
      _library.clear();
      _pages = [];
    }
  }

  Future<void> saveConfig() async {
    try {
      _configPath ??= '${(await _getConfigDirectory()).path}/pages.json';
      final data = {
        'buttons': _library.map((b) => b.toJson()).toList(),
        'pages': _pages.map(_pageToStorage).toList(),
      };
      await File(_configPath!).writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving configuration: $e');
    }
  }

  Map<String, dynamic> _pageToStorage(Page page) => {
        'id': page.id,
        'name': page.name,
        'order': page.order,
        'columns': page.columns,
        'tiles': page.tiles
            .map((t) => {
                  'id': t.id,
                  'buttonId': t.buttonId,
                  'colSpan': t.colSpan,
                  'rowSpan': t.rowSpan,
                })
            .toList(),
      };

  /// Rebuilds a page from normalised storage, resolving tiles against the
  /// library and dropping tiles whose button no longer exists.
  Page? _pageFromStorage(Map<String, dynamic> json) {
    final tiles = <Tile>[];
    for (final t in (json['tiles'] as List<dynamic>? ?? const [])) {
      final map = t as Map<String, dynamic>;
      final button = getButton(map['buttonId'] as String? ?? '');
      if (button == null) continue;
      tiles.add(Tile(
        id: map['id'] as String?,
        button: button,
        colSpan: map['colSpan'] as int? ?? 1,
        rowSpan: map['rowSpan'] as int? ?? 1,
      ));
    }
    return Page(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled',
      order: json['order'] as int? ?? 0,
      columns: json['columns'] as int? ?? 4,
      tiles: tiles,
    );
  }

  Future<Directory> _getConfigDirectory() async {
    final base = (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/marco_deck');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // --- Library ---------------------------------------------------------------

  Button? getButton(String id) {
    for (final b in _library) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Adds a button to the library.
  void addLibraryButton(Button button) {
    _library.add(button);
    saveConfig();
  }

  /// Updates a library button in place so every tile that places it reflects
  /// the change.
  bool updateButton(Button updated) {
    final index = _library.indexWhere((b) => b.id == updated.id);
    if (index == -1) return false;
    _library[index] = updated;
    // Re-point any tiles that referenced the old object.
    for (final page in _pages) {
      for (var i = 0; i < page.tiles.length; i++) {
        if (page.tiles[i].buttonId == updated.id) {
          page.tiles[i] = Tile(
            id: page.tiles[i].id,
            button: updated,
            colSpan: page.tiles[i].colSpan,
            rowSpan: page.tiles[i].rowSpan,
          );
        }
      }
    }
    saveConfig();
    return true;
  }

  /// Deletes a library button and removes its tiles from every page.
  bool deleteButton(String id) {
    final existed = _library.any((b) => b.id == id);
    if (!existed) return false;
    _library.removeWhere((b) => b.id == id);
    for (final page in _pages) {
      page.tiles.removeWhere((t) => t.buttonId == id);
    }
    saveConfig();
    return true;
  }

  // --- Pages -----------------------------------------------------------------

  Page? getPage(String id) {
    for (final p in _pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPage(Page page) {
    _pages.add(page);
    saveConfig();
  }

  bool updatePage(Page updated) {
    final index = _pages.indexWhere((p) => p.id == updated.id);
    if (index == -1) return false;
    _pages[index] = updated;
    saveConfig();
    return true;
  }

  bool deletePage(String id) {
    final before = _pages.length;
    _pages.removeWhere((p) => p.id == id);
    final deleted = _pages.length < before;
    if (deleted) saveConfig();
    return deleted;
  }

  void reorderPages(List<Page> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
    }
    _pages = List.from(newOrder);
    saveConfig();
  }

  // --- Tiles (page composition) ----------------------------------------------

  /// Places [buttonId] on [pageId] at the given size and returns the new tile.
  Tile? addTile(String pageId, String buttonId, {int colSpan = 1, int rowSpan = 1}) {
    final page = getPage(pageId);
    final button = getButton(buttonId);
    if (page == null || button == null) return null;
    final tile = Tile(button: button, colSpan: colSpan, rowSpan: rowSpan);
    page.tiles.add(tile);
    saveConfig();
    return tile;
  }

  bool removeTile(String pageId, String tileId) {
    final page = getPage(pageId);
    if (page == null) return false;
    final before = page.tiles.length;
    page.tiles.removeWhere((t) => t.id == tileId);
    final removed = page.tiles.length < before;
    if (removed) saveConfig();
    return removed;
  }

  bool resizeTile(String pageId, String tileId, int colSpan, int rowSpan) {
    final page = getPage(pageId);
    if (page == null) return false;
    final tile = page.tiles.firstWhere(
      (t) => t.id == tileId,
      orElse: () => Tile(button: Button(name: '', iconName: '')),
    );
    if (tile.button.name.isEmpty && tile.buttonId.isEmpty) return false;
    tile.colSpan = colSpan.clamp(1, page.columns);
    tile.rowSpan = rowSpan.clamp(1, 6);
    saveConfig();
    return true;
  }

  /// Moves the tile at [oldIndex] to [newIndex] within a page.
  bool reorderTiles(String pageId, int oldIndex, int newIndex) {
    final page = getPage(pageId);
    if (page == null) return false;
    if (oldIndex < 0 || oldIndex >= page.tiles.length) return false;
    final tile = page.tiles.removeAt(oldIndex);
    page.tiles.insert(newIndex.clamp(0, page.tiles.length), tile);
    saveConfig();
    return true;
  }

  // --- Defaults --------------------------------------------------------------

  void _createDefaults() {
    Button cmd(String name, String icon, String command, [String color = '#3B82F6']) =>
        Button(
          name: name,
          iconName: icon,
          color: color,
          actions: [ButtonAction(type: ActionType.command, command: command)],
        );

    final browser = cmd(
      'Open Browser',
      PiconsRegular.globe.codePoint.toString(),
      Platform.isWindows
          ? 'start chrome'
          : (Platform.isMacOS ? 'open -a "Google Chrome"' : 'google-chrome'),
    );
    final notes = cmd(
      'Open Notes',
      PiconsRegular.note.codePoint.toString(),
      Platform.isWindows
          ? 'notepad'
          : (Platform.isMacOS ? 'open -a TextEdit' : 'gedit'),
      '#10B981',
    );
    final sysInfo = cmd(
      'System Info',
      PiconsRegular.desktop.codePoint.toString(),
      Platform.isWindows ? 'systeminfo' : 'uname -a',
      '#F59E0B',
    );

    // A single combined "System Monitor" tile (CPU/RAM/Disk/Uptime) on the
    // default System page.
    final monitor = systemMonitorPreset();

    // Showcase a few built-in catalog presets out of the box: a Media page and
    // page-navigation tiles. Resolve them from a single catalog build so each
    // Button keeps a stable id across the library and its placements.
    final catalog = buttonPresetCatalog();
    List<Button> category(String name) =>
        catalog.firstWhere((c) => c.name == name).buttons;
    Button media(String name) =>
        category('Media').firstWhere((b) => b.name == name);
    Button nav(String name) =>
        category('Navigation').firstWhere((b) => b.name == name);

    final playPause = media('Play / Pause');
    final prevTrack = media('Previous');
    final nextTrack = media('Next');
    final mute = media('Mute');
    final volDown = media('Volume Down');
    final volUp = media('Volume Up');
    final nextPage = nav('Next Page');
    final prevPage = nav('Previous Page');

    // Individual live-info tiles (clock, network) for the System page.
    final presetTiles = systemPresetButtons();
    Button sysState(String stateId) =>
        presetTiles.firstWhere((b) => b.stateBinding?.stateId == stateId);
    final clock = sysState('clock');
    final network = sysState('net');

    _library.addAll([
      browser, notes, sysInfo, monitor,
      playPause, prevTrack, nextTrack, mute, volDown, volUp,
      nextPage, prevPage, clock, network,
    ]);
    _pages = [
      Page(name: 'Applications', order: 0, columns: 4, tiles: [
        Tile(button: browser, colSpan: 2),
        Tile(button: notes),
        Tile(button: nextPage),
      ]),
      Page(name: 'Media', order: 1, columns: 4, tiles: [
        Tile(button: prevTrack),
        Tile(button: playPause),
        Tile(button: nextTrack),
        Tile(button: volDown),
        Tile(button: mute),
        Tile(button: volUp),
        Tile(button: nextPage),
      ]),
      Page(name: 'System', order: 2, columns: 4, tiles: [
        Tile(button: monitor, colSpan: 2, rowSpan: 2),
        Tile(button: clock),
        Tile(button: network, colSpan: 2),
        Tile(button: sysInfo),
        Tile(button: prevPage),
      ]),
    ];
  }
}
