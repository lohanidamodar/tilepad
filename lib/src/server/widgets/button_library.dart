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

/// Shows the "add button" picker as a modal sheet: lists every library button
/// to place on the page, plus a "New button" entry to author one.
///
/// Returns a [PickerResult] describing the user's choice, or null if dismissed.
Future<PickerResult?> showButtonPicker(
  BuildContext context, {
  required MarcoServer server,
}) {
  return showModalBottomSheet<PickerResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ButtonPickerSheet(server: server),
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

class _ButtonPickerSheet extends StatefulWidget {
  final MarcoServer server;
  const _ButtonPickerSheet({required this.server});

  @override
  State<_ButtonPickerSheet> createState() => _ButtonPickerSheetState();
}

class _ButtonPickerSheetState extends State<_ButtonPickerSheet> {
  String _query = '';

  bool _matches(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query.toLowerCase());

  /// Header row for a section of the picker list.
  Widget _sectionHeader(String label) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, t.space.md, 0, t.space.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: t.color.textMuted,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  /// A picker row for a ready-made preset button. Selecting it returns a
  /// [PickerResult.preset] so the caller adds it to the library and places it.
  Widget _presetRow(models.Button preset, String subtitle) {
    final t = context.tokens;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _ButtonBadge(button: preset),
      title: Text(preset.name),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: t.color.textMuted),
      ),
      onTap: () => Navigator.of(context).pop(PickerResult.preset(preset)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final library = widget.server.libraryButtons;

    // System metrics live only in the SYSTEM INFO section, and the LIBRARY
    // section shows only the user's own buttons. Keeping the two sets disjoint
    // means a placed metric never appears in both sections, and old duplicate
    // system buttons (from earlier placements) don't clutter the library list.
    final presets = systemPresetButtons();
    final customLibrary = library
        .where((b) => b.stateBinding?.pluginId != systemSourceId)
        .toList();

    final filteredPresets =
        presets.where((p) => _matches(p.name)).toList();
    final filteredLibrary = customLibrary
        .where((b) => _matches(b.name) || _matches(_summary(b)))
        .toList();

    // Built-in catalog (Media, System, Apps, …), filtered by the search query.
    final catalog = [
      for (final category in buttonPresetCatalog())
        (
          name: category.name,
          buttons:
              category.buttons.where((b) => _matches(b.name)).toList(),
        ),
    ].where((c) => c.buttons.isNotEmpty).toList();

    // Presets contributed by ENABLED plugins (hidden when a plugin is disabled).
    final pluginCategories = [
      for (final plugin in widget.server.plugins)
        if (plugin.enabled && plugin.manifest.presets.isNotEmpty)
          (
            name: plugin.manifest.name,
            buttons: pluginPresetButtons(
              plugin.manifest.id,
              plugin.manifest.presets,
            ).where((b) => _matches(b.name)).toList(),
          ),
    ].where((c) => c.buttons.isNotEmpty).toList();

    final noResults = _query.isNotEmpty &&
        filteredPresets.isEmpty &&
        filteredLibrary.isEmpty &&
        catalog.isEmpty &&
        pluginCategories.isEmpty;

    return SafeArea(
      child: Padding(
        // Keep the sheet above the keyboard when the search field is focused.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.xl,
              t.space.xs,
              t.space.xl,
              t.space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add button', style: textTheme.titleLarge),
                SizedBox(height: t.space.xs),
                Text(
                  'Place a button from your library, or create a new one.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: t.color.textMuted,
                  ),
                ),
                SizedBox(height: t.space.md),
                TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search buttons',
                    prefixIcon: Icon(Icons.search, size: t.icon.md),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, size: t.icon.md),
                            onPressed: () => setState(() => _query = ''),
                            tooltip: 'Clear',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: t.radius.brSm,
                    ),
                  ),
                ),
                SizedBox(height: t.space.sm),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: t.icon.xl + t.space.sm,
                          height: t.icon.xl + t.space.sm,
                          decoration: BoxDecoration(
                            color: t.color.accentSubtle,
                            borderRadius: t.radius.brSm,
                          ),
                          child: Icon(
                            Icons.add,
                            size: t.icon.lg,
                            color: t.color.accent,
                          ),
                        ),
                        title: const Text('New button'),
                        subtitle: Text(
                          'Author a new button and place it',
                          style: textTheme.labelMedium
                              ?.copyWith(color: t.color.textMuted),
                        ),
                        onTap: () => Navigator.of(context)
                            .pop(const PickerResult.create()),
                      ),
                      if (filteredPresets.isNotEmpty)
                        _sectionHeader('SYSTEM INFO'),
                      for (final preset in filteredPresets)
                        _presetRow(preset, 'Live system metric'),
                      for (final category in catalog) ...[
                        _sectionHeader(category.name.toUpperCase()),
                        for (final preset in category.buttons)
                          _presetRow(preset, _summary(preset)),
                      ],
                      for (final category in pluginCategories) ...[
                        _sectionHeader(category.name.toUpperCase()),
                        for (final preset in category.buttons)
                          _presetRow(
                            preset,
                            preset.stateBinding != null
                                ? 'Live tile'
                                : 'Plugin action',
                          ),
                      ],
                      if (filteredLibrary.isNotEmpty) ...[
                        _sectionHeader('LIBRARY'),
                        for (final button in filteredLibrary)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _ButtonBadge(button: button),
                            title: Text(button.name),
                            subtitle: Text(
                              _summary(button),
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium
                                  ?.copyWith(color: t.color.textMuted),
                            ),
                            onTap: () => Navigator.of(context)
                                .pop(PickerResult.existing(button)),
                          ),
                      ],
                      if (noResults)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: t.space.lg),
                          child: Center(
                            child: Text(
                              'No buttons match "$_query"',
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: t.color.textMuted),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
