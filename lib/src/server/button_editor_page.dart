// filepath: g:\dev\projects\macro-deck\lib\src\server\button_editor_page.dart
import 'package:flutter/material.dart';
import '../utils/macro_icons.dart';

import '../design/design.dart';
import '../models/button.dart';
import '../utils/icon_picker_dialog.dart';
import 'action_editor_page.dart';
import 'server.dart';
import 'system_info.dart';

/// Page for editing a macro button's properties
class ButtonEditorPage extends StatefulWidget {
  /// The button to edit, null if creating a new button
  final Button? button;

  /// The server, used to offer plugin actions and live-tile state bindings.
  final MarcoServer server;

  /// Callback when button is saved
  final Function(Button button) onSave;

  /// Creates a new button editor page
  const ButtonEditorPage({
    super.key,
    this.button,
    required this.server,
    required this.onSave,
  });

  @override
  State<ButtonEditorPage> createState() => _ButtonEditorPageState();
}

class _ButtonEditorPageState extends State<ButtonEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = MacroIcons.defaultId;
  String _selectedColor = '#4285F4';

  // List of actions for this button
  List<ButtonAction> _actions = [];

  /// Actions run when the button is held (long-pressed) on the device.
  List<ButtonAction> _longPressActions = [];

  /// Whether this button toggles between two faces.
  bool _isToggle = false;

  /// Appearance and actions of the toggled-on face.
  final _toggleNameController = TextEditingController();
  String _toggleIcon = '';
  String _toggleColor = '';
  List<ButtonAction> _toggleActions = [];

  /// Optional live-tile binding to a plugin state.
  StateBinding? _stateBinding;

  final List<Color> _presetColors = [
    const Color(0xFF4285F4), // Google Blue
    const Color(0xFF34A853), // Google Green
    const Color(0xFFFBBC05), // Google Yellow
    const Color(0xFFEA4335), // Google Red
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue Grey
  ];

  final List<IconData> _presetIcons = MacroIcons.presets;

  @override
  void initState() {
    super.initState();

    // Initialize form with existing button data if editing
    if (widget.button != null) {
      _nameController.text = widget.button!.name;
      _selectedIcon = widget.button!.iconName;
      _selectedColor = widget.button!.color;

      // Copy actions (including plugin fields so editing preserves them)
      _actions = _copyActions(widget.button!.actions);
      _longPressActions = _copyActions(widget.button!.longPressActions);
      _stateBinding = widget.button!.stateBinding;

      final toggle = widget.button!.toggleState;
      if (toggle != null) {
        _isToggle = true;
        _toggleNameController.text = toggle.name;
        _toggleIcon = toggle.iconName;
        _toggleColor = toggle.color;
        _toggleActions = _copyActions(toggle.actions);
      }
    }
  }

  /// Deep-copies actions so editing doesn't mutate the stored button until
  /// save.
  List<ButtonAction> _copyActions(List<ButtonAction> actions) =>
      actions.map((a) => a.copy()).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _toggleNameController.dispose();
    super.dispose();
  }

  /// Saves the button and returns it
  void _saveButton() {
    if (_formKey.currentState!.validate()) {
      if (_actions.isEmpty) {
        // Show error if no actions are defined
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please add at least one action to the button'),
            backgroundColor: context.tokens.color.danger,
          ),
        );
        return;
      }

      final button = Button(
        id: widget.button?.id,
        name: _nameController.text.trim(),
        iconName: _selectedIcon,
        actions: _actions,
        color: _selectedColor,
        stateBinding: _stateBinding,
        toggleState: _isToggle
            ? ToggleState(
                name: _toggleNameController.text.trim(),
                iconName: _toggleIcon,
                color: _toggleColor,
                actions: _toggleActions,
              )
            : null,
        // Keep the current face when editing an existing toggle button.
        toggled: _isToggle && (widget.button?.toggled ?? false),
        longPressActions: _longPressActions,
      );

      widget.onSave(button);
      Navigator.of(context).pop();
    }
  }

  /// Converts a color to a hex string
  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Converts a hex string to a Color, falling back to the default colour
  /// when the stored value is malformed.
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

  /// Handles icon selection and stores the code point
  void _selectIcon(IconData icon) {
    setState(() {
      // Store just the code point as a string
      _selectedIcon = icon.codePoint.toString();
    });
  }

  /// Opens the extended icon picker dialog with search functionality
  Future<void> _showExtendedIconPicker() async {
    final result = await showDialog<IconData>(
      context: context,
      builder: (context) => const IconPickerDialog(),
    );

    if (result != null) {
      _selectIcon(result);
    }
  }

  /// Navigate to action editor page. Edits the action at [index] in [list]
  /// (the main, toggle-face, or long-press action list), or appends when
  /// [index] is out of range.
  Future<void> _navigateToActionEditor(
    List<ButtonAction> list,
    ButtonAction? action,
    int index,
  ) async {
    final result = await Navigator.push<ButtonAction>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ActionEditorPage(action: action, server: widget.server),
      ),
    );

    if (result != null) {
      setState(() {
        if (index >= 0 && index < list.length) {
          // Update existing action
          list[index] = result;
        } else {
          // Add new action
          list.add(result);
        }
      });
    }
  }

  /// Deletes an action from [list]
  void _deleteAction(List<ButtonAction> list, int index) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Action'),
            content: const Text('Are you sure you want to delete this action?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.color.danger,
                ),
                onPressed: () {
                  setState(() {
                    list.removeAt(index);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Describes an action for display
  String _getActionDescription(ButtonAction action) {
    switch (action.type) {
      case ActionType.command:
        return 'Command: ${action.command}';
      case ActionType.commandPreset:
        return 'Preset: ${action.command}';
      case ActionType.keystroke:
        final modifierText =
            action.modifiers.isNotEmpty
                ? '${action.modifiers.map((m) => m.toUpperCase()).join('+')}+'
                : '';
        return 'Keystroke: $modifierText${action.key.toUpperCase()}';
      case ActionType.promptText:
        return 'Asks the device for text, then types it';
      case ActionType.promptKeystroke:
        return 'Asks the device for a key combo, then sends it';
      case ActionType.selectWindow:
        return 'Lets the device pick a window to bring to front';
      case ActionType.openUrl:
        return 'Opens ${action.command}';
      case ActionType.mediaKey:
        return 'Media key: ${action.key}';
      case ActionType.navigatePage:
        if (action.command.startsWith('page:')) {
          final pageId = action.command.substring('page:'.length);
          final pages = widget.server.pages.where((p) => p.id == pageId);
          return pages.isEmpty
              ? 'Go to a removed page'
              : 'Go to page "${pages.first.name}"';
        }
        return 'Go to ${action.command} page';
      case ActionType.plugin:
        return 'Plugin: ${action.pluginActionId}';
      case ActionType.delay:
        return 'Wait ${action.command} ms';
    }
  }

  /// Gets the name of an action type
  String _getActionTypeString(ActionType type) {
    switch (type) {
      case ActionType.command:
        return 'Custom Command';
      case ActionType.commandPreset:
        return 'Preset Command';
      case ActionType.keystroke:
        return 'Keystroke';
      case ActionType.promptText:
        return 'Prompt for Text';
      case ActionType.promptKeystroke:
        return 'Prompt for Key Combo';
      case ActionType.selectWindow:
        return 'Select Window';
      case ActionType.openUrl:
        return 'Open URL';
      case ActionType.mediaKey:
        return 'Media Key';
      case ActionType.navigatePage:
        return 'Navigate Page';
      case ActionType.plugin:
        return 'Plugin Action';
      case ActionType.delay:
        return 'Delay';
    }
  }

  /// Gets an icon for an action type
  IconData _getActionTypeIcon(ActionType type) {
    switch (type) {
      case ActionType.command:
        return Icons.terminal;
      case ActionType.commandPreset:
        return Icons.list_alt;
      case ActionType.keystroke:
        return Icons.keyboard;
      case ActionType.promptText:
        return Icons.keyboard_alt_outlined;
      case ActionType.promptKeystroke:
        return Icons.touch_app_outlined;
      case ActionType.selectWindow:
        return Icons.web_asset;
      case ActionType.openUrl:
        return Icons.link;
      case ActionType.mediaKey:
        return Icons.play_circle_outline;
      case ActionType.navigatePage:
        return Icons.swap_horiz;
      case ActionType.plugin:
        return Icons.extension;
      case ActionType.delay:
        return Icons.timer_outlined;
    }
  }

  /// Builds a titled, reorderable list of actions with add/edit/delete. Used
  /// for the main actions, the toggled-on face's actions, and the long-press
  /// actions.
  Widget _buildActionsCard({
    required String title,
    IconData? icon,
    String? subtitle,
    required List<ButtonAction> actions,
    required String emptyText,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: TextButton.icon(
        onPressed: () => _navigateToActionEditor(actions, null, -1),
        icon: Icon(Icons.add, size: tokens.icon.sm),
        label: const Text('Add'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
      flush: true,
      children: [
        if (actions.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space.lg,
              0,
              tokens.space.lg,
              tokens.space.sm,
            ),
            child: Text(
              emptyText,
              style: textTheme.bodySmall
                  ?.copyWith(color: tokens.color.textMuted),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = actions.removeAt(oldIndex);
                actions.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                key: ValueKey(action.id),
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.space.lg,
                ),
                leading: Container(
                  width: tokens.space.xxxl,
                  height: tokens.space.xxxl,
                  decoration: BoxDecoration(
                    color: tokens.color.accentSubtle,
                    borderRadius: tokens.radius.brSm,
                  ),
                  child: Icon(
                    _getActionTypeIcon(action.type),
                    size: tokens.icon.sm,
                    color: tokens.color.accent,
                  ),
                ),
                title: Text(
                  _getActionTypeString(action.type),
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: tokens.typeScale.wSemibold),
                ),
                subtitle: Text(
                  _getActionDescription(action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall
                      ?.copyWith(color: tokens.color.textSecondary),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, size: tokens.icon.md),
                  visualDensity: VisualDensity.compact,
                  color: tokens.color.textMuted,
                  onPressed: () => _deleteAction(actions, index),
                  tooltip: 'Delete',
                ),
                onTap: () => _navigateToActionEditor(actions, action, index),
              );
            },
          ),
      ],
    );
  }

  /// Builds the toggle section: a switch to make this a two-face button plus
  /// the second face's optional name/icon/color overrides. The face's action
  /// list renders as its own section below this one.
  Widget _buildToggleSection() {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return SectionCard(
      icon: Icons.toggle_on_outlined,
      title: 'Toggle',
      subtitle: _isToggle
          ? 'Each press alternates faces. Leave a field empty to keep the '
              'normal appearance.'
          : 'Two-state button (e.g. Mute / Unmute): each press runs the '
              'active face\'s actions and flips it on every device.',
      trailing: Switch(
        value: _isToggle,
        onChanged: (value) => setState(() => _isToggle = value),
      ),
      children: [
        if (_isToggle) ...[
          TextFormField(
            controller: _toggleNameController,
            decoration: const InputDecoration(
              labelText: 'Toggled-on name (optional)',
              hintText: 'e.g. Unmute',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          SizedBox(height: tokens.space.lg),
          Row(
            children: [
              Text('Icon', style: theme.textTheme.bodyMedium),
              SizedBox(width: tokens.space.md),
              if (_toggleIcon.isNotEmpty)
                Icon(_getIconData(_toggleIcon), size: tokens.icon.lg)
              else
                Text(
                  'same as normal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.color.textMuted,
                  ),
                ),
              SizedBox(width: tokens.space.sm),
              TextButton(
                onPressed: () async {
                  final result = await showDialog<IconData>(
                    context: context,
                    builder: (context) => const IconPickerDialog(),
                  );
                  if (result != null) {
                    setState(() => _toggleIcon = MacroIcons.idFor(result));
                  }
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Browse'),
              ),
              if (_toggleIcon.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _toggleIcon = ''),
                  icon: Icon(Icons.clear, size: tokens.icon.sm),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Use the normal icon',
                ),
            ],
          ),
          SizedBox(height: tokens.space.md),
          Text('Color', style: theme.textTheme.bodyMedium),
          SizedBox(height: tokens.space.sm),
          _buildColorSwatches(
            selected: _toggleColor,
            onChanged: (hex) => setState(() => _toggleColor = hex),
            allowInherit: true,
          ),
        ],
      ],
    );
  }

  /// Builds the optional "Live Tile" section that binds the button to a plugin
  /// state so the client shows live text/icon.
  Widget _buildLiveTileSection() {
    // Built-in system metrics + states exposed by installed plugins.
    final states = <_StateOption>[
      for (final s in systemStates)
        _StateOption(
          pluginId: systemSourceId,
          stateId: s.id,
          label: 'System: ${s.label}',
        ),
    ];
    for (final plugin in widget.server.plugins) {
      for (final state in plugin.manifest.states) {
        states.add(_StateOption(
          pluginId: plugin.manifest.id,
          stateId: state.id,
          label: '${plugin.manifest.name}: ${state.label}',
        ));
      }
    }

    final tokens = context.tokens;
    final currentKey = _stateBinding == null
        ? null
        : '${_stateBinding!.pluginId}|${_stateBinding!.stateId}';
    final hasMatch = states.any((s) => s.key == currentKey);

    return SectionCard(
      icon: Icons.sensors_outlined,
      title: 'Live tile',
      subtitle: states.isEmpty
          ? 'Install and enable a plugin that exposes live states to drive '
              'this button with live data.'
          : 'Show a live value from the system or a plugin on this button.',
      children: [
        if (states.isNotEmpty) ...[
          DropdownButtonFormField<String?>(
            initialValue: hasMatch ? currentKey : null,
            decoration: const InputDecoration(
              labelText: 'Bound state',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('None')),
              for (final s in states)
                DropdownMenuItem<String?>(
                    value: s.key, child: Text(s.label)),
            ],
            onChanged: (value) {
              setState(() {
                if (value == null) {
                  _stateBinding = null;
                } else {
                  final match =
                      states.firstWhere((s) => s.key == value);
                  _stateBinding = StateBinding(
                    pluginId: match.pluginId,
                    stateId: match.stateId,
                    mode: _stateBinding?.mode ?? StateBindingMode.title,
                  );
                }
              });
            },
          ),
          if (_stateBinding != null) ...[
            SizedBox(height: tokens.space.md),
            SegmentedButton<StateBindingMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: StateBindingMode.title,
                  label: Text('Title'),
                  icon: Icon(Icons.title),
                ),
                ButtonSegment(
                  value: StateBindingMode.icon,
                  label: Text('Icon'),
                  icon: Icon(Icons.image_outlined),
                ),
              ],
              selected: {_stateBinding!.mode},
              onSelectionChanged: (modes) {
                setState(() {
                  _stateBinding = StateBinding(
                    pluginId: _stateBinding!.pluginId,
                    stateId: _stateBinding!.stateId,
                    mode: modes.first,
                  );
                });
              },
            ),
          ],
        ],
      ],
    );
  }

  /// One shared swatch row for both the main color and the toggled-on color,
  /// so the two pickers stay visually identical.
  Widget _buildColorSwatches({
    required String selected,
    required ValueChanged<String> onChanged,
    bool allowInherit = false,
  }) {
    final tokens = context.tokens;
    final swatchSize = tokens.space.xxxl;

    Widget swatch({
      required bool isSelected,
      required VoidCallback onTap,
      Color? color,
      Widget? child,
    }) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: swatchSize,
          height: swatchSize,
          decoration: BoxDecoration(
            color: color ?? tokens.color.surfaceSubtle,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? tokens.color.borderStrong
                  : tokens.color.border,
              width: isSelected ? tokens.border.focus : tokens.border.hairline,
            ),
          ),
          child: child ??
              (isSelected
                  ? Icon(Icons.check,
                      size: tokens.icon.sm, color: Colors.white)
                  : null),
        ),
      );
    }

    return Wrap(
      spacing: tokens.space.sm,
      runSpacing: tokens.space.sm,
      children: [
        if (allowInherit)
          swatch(
            isSelected: selected.isEmpty,
            onTap: () => onChanged(''),
            child: Icon(
              Icons.block,
              size: tokens.icon.sm,
              color: tokens.color.textMuted,
            ),
          ),
        for (final color in _presetColors)
          swatch(
            isSelected: selected == _colorToHex(color),
            onTap: () => onChanged(_colorToHex(color)),
            color: color,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.button == null ? 'Create Button' : 'Edit Button'),
        actions: [
          TextButton.icon(
            onPressed: _saveButton,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
          SizedBox(width: tokens.space.sm),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(tokens.space.lg),
          children: [
            // Button name
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Button Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              // Rebuild so the live button preview reflects the typed name.
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            SizedBox(height: tokens.space.lg),

            // Actions section
            _buildActionsCard(
              icon: Icons.bolt_outlined,
              title: 'Actions (${_actions.length})',
              actions: _actions,
              emptyText: 'No actions yet — add one to get started.',
            ),
            SizedBox(height: tokens.space.lg),

            // Toggle (two-face) section, with the second face's actions as a
            // sibling section so cards never nest.
            _buildToggleSection(),
            if (_isToggle) ...[
              SizedBox(height: tokens.space.lg),
              _buildActionsCard(
                icon: Icons.toggle_on_outlined,
                title: 'Toggled-on actions (${_toggleActions.length})',
                actions: _toggleActions,
                emptyText:
                    'No separate actions — both faces run the main actions.',
              ),
            ],
            SizedBox(height: tokens.space.lg),

            // Long-press actions section
            _buildActionsCard(
              icon: Icons.touch_app_outlined,
              title: 'Hold actions (${_longPressActions.length})',
              subtitle:
                  'Run a different action set when the button is held on the '
                  'device instead of tapped.',
              actions: _longPressActions,
              emptyText: 'No hold actions — holding behaves like a tap.',
            ),
            SizedBox(height: tokens.space.lg),

            // Live tile section (plugin-driven dynamic title/icon)
            _buildLiveTileSection(),
            SizedBox(height: tokens.space.lg),

            // Button appearance section
            SectionCard(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              children: [
                // Button preview
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: _hexToColor(_selectedColor),
                      borderRadius: tokens.radius.brLg,
                    ),
                    padding: EdgeInsets.all(tokens.space.sm),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconData(_selectedIcon),
                          size: tokens.space.xxxl,
                          color: Colors.white,
                        ),
                        SizedBox(height: tokens.space.sm),
                        Text(
                          _nameController.text.isEmpty
                              ? 'Button Name'
                              : _nameController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: tokens.typeScale.wSemibold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.space.xl),

                // Color selection
                Text('Color', style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(height: tokens.space.sm),
                _buildColorSwatches(
                  selected: _selectedColor,
                  onChanged: (hex) => setState(() => _selectedColor = hex),
                ),
                SizedBox(height: tokens.space.xl),

                // Icon selection
                Row(
                  children: [
                    Text('Icon', style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showExtendedIconPicker,
                      icon: Icon(Icons.search, size: tokens.icon.sm),
                      label: const Text('Browse all'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space.sm),

                // Icons grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: tokens.space.sm,
                    crossAxisSpacing: tokens.space.sm,
                  ),
                  itemCount: _presetIcons.length,
                  itemBuilder: (context, index) {
                    final icon = _presetIcons[index];
                    final iconString = icon.codePoint.toString();
                    final isSelected = iconString == _selectedIcon;

                    return InkWell(
                      onTap: () {
                        _selectIcon(icon);
                      },
                      borderRadius: tokens.radius.brSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _hexToColor(_selectedColor)
                              : tokens.color.surfaceSubtle,
                          borderRadius: tokens.radius.brSm,
                        ),
                        child: Icon(
                          icon,
                          size: tokens.icon.lg,
                          color: isSelected
                              ? Colors.white
                              : tokens.color.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves a stored icon identifier to its Phosphor [IconData].
  IconData _getIconData(String iconName) => MacroIcons.resolve(iconName);
}

/// A selectable plugin state for the live-tile dropdown.
class _StateOption {
  final String pluginId;
  final String stateId;
  final String label;
  _StateOption({
    required this.pluginId,
    required this.stateId,
    required this.label,
  });
  String get key => '$pluginId|$stateId';
}
