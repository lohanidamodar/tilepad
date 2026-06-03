import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../models/button.dart' as models;
import '../../utils/macro_icons.dart';
import '../button_editor_page.dart';
import '../button_presets.dart';
import '../server.dart';
import '../system_info.dart';

/// Converts a hex string to a Color, falling back to the default color when the
/// stored value is malformed.
Color _hexToColor(String hexString) {
  var hexColor = hexString.replaceAll('#', '').trim();
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }
  final value = int.tryParse(hexColor, radix: 16);
  if (value == null || hexColor.length != 8) {
    return const Color(0xFF4285F4);
  }
  return Color(value);
}

/// A short description of a button's first action for list subtitles.
String _summary(models.Button button) {
  if (button.actions.isEmpty) return 'No actions';
  final action = button.actions.first;
  switch (action.type) {
    case models.ActionType.command:
      return 'Command: ${action.command}';
    case models.ActionType.commandPreset:
      return 'Preset: ${action.command}';
    case models.ActionType.keystroke:
      final mods = action.modifiers.isNotEmpty
          ? '${action.modifiers.map((m) => m.toUpperCase()).join('+')}+'
          : '';
      return 'Keystroke: $mods${action.key.toUpperCase()}';
    case models.ActionType.promptText:
      return 'Prompt for text';
    case models.ActionType.promptKeystroke:
      return 'Prompt for key combo';
    case models.ActionType.selectWindow:
      return 'Select a window to focus';
    case models.ActionType.openUrl:
      return 'Open ${action.command}';
    case models.ActionType.mediaKey:
      return 'Media: ${action.key}';
    case models.ActionType.navigatePage:
      return 'Go to ${action.command} page';
    case models.ActionType.plugin:
      return 'Plugin: ${action.pluginActionId}';
  }
}

/// A small icon/color leading badge shared by the picker and manager rows.
class _ButtonBadge extends StatelessWidget {
  final models.Button button;
  const _ButtonBadge({required this.button});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: t.icon.xl + t.space.sm,
      height: t.icon.xl + t.space.sm,
      decoration: BoxDecoration(
        color: _hexToColor(button.color),
        borderRadius: t.radius.brSm,
      ),
      child: Icon(
        MacroIcons.resolve(button.iconName),
        size: t.icon.lg,
        color: Colors.white,
      ),
    );
  }
}

/// Opens the full-page "add button" picker: a searchable, category-filtered
/// grid of system presets, the built-in catalog, enabled plugins' presets and
/// the user's library, plus a "New button" entry.
///
/// Supports multi-select — returns every chosen [PickerResult] (in selection
/// order), or null if dismissed. Choosing "New button" returns a single
/// [PickerResult.create].
Future<List<PickerResult>?> showButtonPicker(
  BuildContext context, {
  required MarcoServer server,
}) {
  return Navigator.of(context).push<List<PickerResult>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _ButtonPickerPage(server: server),
    ),
  );
}

/// The outcome of the add-button picker.
class PickerResult {
  /// An existing library button was chosen to be placed.
  final models.Button? existing;

  /// The user asked to author a brand new button.
  final bool createNew;

  /// A ready-made preset (e.g. a system-info tile) to add to the library and
  /// place. Not yet in the library.
  final models.Button? preset;

  const PickerResult.existing(models.Button button)
      : existing = button,
        createNew = false,
        preset = null;

  const PickerResult.create()
      : existing = null,
        createNew = true,
        preset = null;

  const PickerResult.preset(models.Button button)
      : existing = null,
        createNew = false,
        preset = button;
}

/// One selectable entry in the picker grid.
class _PickerItem {
  final models.Button button;
  final String subtitle;

  /// True when this is an existing library button (returns [PickerResult.existing]);
  /// otherwise it's a preset (returns [PickerResult.preset]).
  final bool isLibrary;

  const _PickerItem(this.button, this.subtitle, {this.isLibrary = false});

  bool get isLive => button.stateBinding != null;

  PickerResult get result =>
      isLibrary ? PickerResult.existing(button) : PickerResult.preset(button);
}

/// A named category of picker items.
class _PickerGroup {
  final String name;
  final List<_PickerItem> items;
  const _PickerGroup(this.name, this.items);
}

const String _kAll = 'All';
const String _kLive = 'Live tiles';

const SliverGridDelegateWithMaxCrossAxisExtent _kGrid =
    SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 150,
  mainAxisExtent: 124,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
);

class _ButtonPickerPage extends StatefulWidget {
  final MarcoServer server;
  const _ButtonPickerPage({required this.server});

  @override
  State<_ButtonPickerPage> createState() => _ButtonPickerPageState();
}

class _ButtonPickerPageState extends State<_ButtonPickerPage> {
  String _query = '';
  String _category = _kAll;

  /// Selected button ids (multi-select). Ids are stable because [_groups] is
  /// built once — preset buttons would otherwise get fresh ids each rebuild.
  final Set<String> _selected = {};

  late final List<_PickerGroup> _groups = _allGroups();

  void _toggle(String id) => setState(() {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      });

  /// Builds every category group: system presets, the built-in catalog,
  /// enabled plugins' presets, then the user's own library.
  List<_PickerGroup> _allGroups() {
    // System metrics live only in their own group; the Library group shows only
    // the user's own (non-system) buttons so nothing appears twice.
    final customLibrary = widget.server.libraryButtons
        .where((b) => b.stateBinding?.pluginId != systemSourceId)
        .toList();
    return [
      _PickerGroup('System Info', [
        for (final b in systemPresetButtons())
          _PickerItem(b, 'Live system metric'),
      ]),
      for (final c in buttonPresetCatalog())
        _PickerGroup(
            c.name, [for (final b in c.buttons) _PickerItem(b, _summary(b))]),
      for (final p in widget.server.plugins)
        if (p.enabled && p.manifest.presets.isNotEmpty)
          _PickerGroup(p.manifest.name, [
            for (final b
                in pluginPresetButtons(p.manifest.id, p.manifest.presets))
              _PickerItem(
                  b, b.stateBinding != null ? 'Live tile' : 'Plugin action'),
          ]),
      _PickerGroup('Library', [
        for (final b in customLibrary)
          _PickerItem(b, _summary(b), isLibrary: true),
      ]),
    ].where((g) => g.items.isNotEmpty).toList();
  }

  bool _matches(_PickerItem item) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return item.button.name.toLowerCase().contains(q) ||
        item.subtitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final groups = _groups;

    final selectedResults = [
      for (final g in groups)
        for (final i in g.items)
          if (_selected.contains(i.button.id)) i.result,
    ];

    final liveCount = groups.fold<int>(
        0, (a, g) => a + g.items.where((i) => i.isLive).length);
    final categories = <({String label, int count})>[
      (label: _kAll, count: groups.fold<int>(0, (a, g) => a + g.items.length)),
      if (liveCount > 0) (label: _kLive, count: liveCount),
      for (final g in groups) (label: g.name, count: g.items.length),
    ];
    final active =
        categories.any((c) => c.label == _category) ? _category : _kAll;

    // Resolve the visible groups for the active category, after search.
    final List<_PickerGroup> visible;
    if (active == _kAll) {
      visible = [
        for (final g in groups)
          _PickerGroup(g.name, g.items.where(_matches).toList()),
      ].where((g) => g.items.isNotEmpty).toList();
    } else if (active == _kLive) {
      final live = [
        for (final g in groups)
          for (final i in g.items)
            if (i.isLive && _matches(i)) i,
      ];
      visible = live.isEmpty ? const [] : [_PickerGroup(_kLive, live)];
    } else {
      final g = groups.firstWhere((g) => g.name == active,
          orElse: () => const _PickerGroup('', []));
      final items = g.items.where(_matches).toList();
      visible = items.isEmpty ? const [] : [_PickerGroup(g.name, items)];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add button'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text('Clear'),
            ),
        ],
      ),
      bottomNavigationBar: selectedResults.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(t.space.lg),
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(selectedResults),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Add ${selectedResults.length} '
                    'button${selectedResults.length == 1 ? '' : 's'}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(t.space.huge),
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                t.space.lg, t.space.md, t.space.lg, t.space.sm),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search buttons',
                prefixIcon: Icon(Icons.search, size: t.icon.md),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, size: t.icon.md),
                        tooltip: 'Clear',
                        onPressed: () => setState(() => _query = ''),
                      ),
                border: OutlineInputBorder(borderRadius: t.radius.brSm),
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 196,
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: t.space.sm),
                    children: [
                      for (final c in categories)
                        _CategoryTile(
                          label: c.label,
                          count: c.count,
                          selected: c.label == active,
                          onTap: () => setState(() => _category = c.label),
                        ),
                    ],
                  ),
                ),
                VerticalDivider(
                    width: t.border.hairline, color: t.color.border),
                Expanded(child: _buildGrid(t, visible, active)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(AppTokens t, List<_PickerGroup> groups, String active) {
    final showNew = active == _kAll || active == 'Library';
    if (groups.isEmpty && !showNew) {
      return Center(
        child: Text(
          _query.isEmpty ? 'Nothing here yet' : 'No buttons match "$_query"',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: t.color.textMuted),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        if (showNew) ...[
          _header(t, 'CREATE'),
          _grid([
            _NewButtonCard(
              onTap: () =>
                  Navigator.of(context).pop([const PickerResult.create()]),
            ),
          ], t),
        ],
        for (final g in groups) ...[
          _header(t, g.name.toUpperCase()),
          _grid([
            for (final item in g.items)
              _ButtonCard(
                button: item.button,
                subtitle: item.subtitle,
                selected: _selected.contains(item.button.id),
                onTap: () => _toggle(item.button.id),
              ),
          ], t),
        ],
        SliverToBoxAdapter(child: SizedBox(height: t.space.xl)),
      ],
    );
  }

  Widget _header(AppTokens t, String label) => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              t.space.lg, t.space.md, t.space.lg, t.space.xs),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: t.color.textMuted,
                  letterSpacing: 0.8,
                ),
          ),
        ),
      );

  Widget _grid(List<Widget> cards, AppTokens t) => SliverPadding(
        padding: EdgeInsets.fromLTRB(t.space.lg, 0, t.space.lg, t.space.sm),
        sliver: SliverGrid(
          gridDelegate: _kGrid,
          delegate: SliverChildListDelegate(cards),
        ),
      );
}

/// A category entry in the picker's left rail.
class _CategoryTile extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.color.accent : t.color.textSecondary;
    return Material(
      color: selected ? t.color.accentSubtle : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.space.lg, vertical: t.space.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: t.color.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A preview card for a button in the picker grid.
class _ButtonCard extends StatelessWidget {
  final models.Button button;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ButtonCard({
    required this.button,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _hexToColor(button.color);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF18181B);
    return InkWell(
      onTap: onTap,
      borderRadius: t.radius.brMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: t.radius.brMd,
                border: selected
                    ? Border.all(color: t.color.accent, width: 3)
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      MacroIcons.resolve(button.iconName),
                      color: onColor,
                      size: t.icon.xl,
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: t.space.xxs,
                      right: t.space.xxs,
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.color.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check,
                            size: t.icon.sm, color: t.color.onAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.xs),
          Text(
            button.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.color.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The "New button" card that authors a fresh button.
class _NewButtonCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewButtonCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: t.radius.brMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DottedBorderBox(
              child: Center(
                child: Icon(Icons.add, color: t.color.accent, size: t.icon.xl),
              ),
            ),
          ),
          SizedBox(height: t.space.xs),
          Text(
            'New button',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'Author your own',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.color.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A subtle dashed-look container (a tinted rounded box) for the New card.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.color.accentSubtle,
        borderRadius: t.radius.brMd,
        border: Border.all(color: t.color.accent.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

/// A screen listing the reusable button library, with edit and delete actions.
///
/// Editing reuses [ButtonEditorPage] (-> [MarcoServer.updateButton]); deleting
/// removes the button from the library and every page that placed it
/// ([MarcoServer.deleteButton]).
class ButtonLibraryScreen extends StatefulWidget {
  final MarcoServer server;
  const ButtonLibraryScreen({super.key, required this.server});

  @override
  State<ButtonLibraryScreen> createState() => _ButtonLibraryScreenState();
}

class _ButtonLibraryScreenState extends State<ButtonLibraryScreen> {
  Future<void> _createButton() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ButtonEditorPage(
          server: widget.server,
          onSave: (button) {
            widget.server.addLibraryButton(button);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editButton(models.Button button) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ButtonEditorPage(
          button: button,
          server: widget.server,
          onSave: (updated) {
            widget.server.updateButton(updated);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteButton(models.Button button) async {
    final t = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Button'),
        content: Text(
          'Delete "${button.name}" from your library? '
          'It will also be removed from every page that uses it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.color.danger,
              foregroundColor: t.color.onAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.server.deleteButton(button.id);
      if (mounted) setState(() {});
    }
  }

  /// Runs a button's actions on the server (no client needed) and reports the
  /// result — handy for testing commands/keystrokes from the desktop.
  Future<void> _runButton(models.Button button) async {
    final t = context.tokens;
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.server.executeButtonLocally(button);
    if (!mounted) return;
    final detail = result.output.isNotEmpty
        ? result.output
        : (result.error.isNotEmpty ? result.error : null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              result.success ? t.color.success : t.color.danger,
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: t.color.onAccent,
                size: t.icon.md,
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Text(
                  detail == null
                      ? (result.success ? 'Ran "${button.name}"' : 'Failed')
                      : '${button.name}: $detail',
                  style: TextStyle(color: t.color.onAccent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final library = widget.server.libraryButtons;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buttons'),
        actions: [
          TextButton.icon(
            onPressed: _createButton,
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
          SizedBox(width: t.space.sm),
        ],
      ),
      body: library.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_outlined,
                    size: t.icon.xl,
                    color: t.color.textMuted,
                  ),
                  SizedBox(height: t.space.md),
                  Text(
                    'Your button library is empty',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: t.color.textMuted),
                  ),
                  SizedBox(height: t.space.md),
                  TextButton.icon(
                    onPressed: _createButton,
                    icon: const Icon(Icons.add),
                    label: const Text('New button'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(t.space.lg),
              itemCount: library.length,
              separatorBuilder: (_, _) =>
                  Divider(height: t.border.hairline, color: t.color.border),
              itemBuilder: (context, index) {
                final button = library[index];
                return ListTile(
                  leading: _ButtonBadge(button: button),
                  title: Text(button.name),
                  subtitle: Text(
                    _summary(button),
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium
                        ?.copyWith(color: t.color.textMuted),
                  ),
                  onTap: () => _editButton(button),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Run on the server (test without a connected client).
                      // Client-only buttons (page navigation, prompts) have
                      // nothing to run here, so the action is hidden for them.
                      if (button.actions.isNotEmpty &&
                          button.navigationTarget == null &&
                          !button.isPrompt)
                        IconButton(
                          onPressed: () => _runButton(button),
                          icon: Icon(Icons.play_arrow_rounded, size: t.icon.md),
                          tooltip: 'Run on server',
                          color: t.color.success,
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        onPressed: () => _editButton(button),
                        icon: Icon(Icons.edit_outlined, size: t.icon.md),
                        tooltip: 'Edit',
                        color: t.color.textMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => _deleteButton(button),
                        icon: Icon(Icons.delete_outline, size: t.icon.md),
                        tooltip: 'Delete',
                        color: t.color.danger,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
