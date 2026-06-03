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
      _actions =
          widget.button!.actions
              .map(
                (action) => ButtonAction(
                  id: action.id,
                  type: action.type,
                  command: action.command,
                  key: action.key,
                  modifiers: List<String>.from(action.modifiers),
                  pluginId: action.pluginId,
                  pluginActionId: action.pluginActionId,
                  settings: Map<String, dynamic>.from(action.settings),
                ),
              )
              .toList();
      _stateBinding = widget.button!.stateBinding;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  /// Navigate to action editor page
  Future<void> _navigateToActionEditor(ButtonAction? action, int index) async {
    final result = await Navigator.push<ButtonAction>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ActionEditorPage(action: action, server: widget.server),
      ),
    );

    if (result != null) {
      setState(() {
        if (index >= 0 && index < _actions.length) {
          // Update existing action
          _actions[index] = result;
        } else {
          // Add new action
          _actions.add(result);
        }
      });
    }
  }

  /// Deletes an action
  void _deleteAction(int index) {
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
                    _actions.removeAt(index);
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
      case ActionType.plugin:
        return 'Plugin: ${action.pluginActionId}';
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
      case ActionType.plugin:
        return 'Plugin Action';
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
      case ActionType.plugin:
        return Icons.extension;
    }
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

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final currentKey = _stateBinding == null
        ? null
        : '${_stateBinding!.pluginId}|${_stateBinding!.stateId}';
    final hasMatch = states.any((s) => s.key == currentKey);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.brMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(tokens.space.lg),
            color: theme.colorScheme.primary,
            child: Text(
              'Live Tile (optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tokens.space.lg),
            child: states.isEmpty
                ? Text(
                    'Install and enable a plugin that exposes live states to '
                    'drive this button with live data.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show a live value from a plugin on this button.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      SizedBox(height: tokens.space.md),
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
                                mode: _stateBinding?.mode ??
                                    StateBindingMode.title,
                              );
                            }
                          });
                        },
                      ),
                      if (_stateBinding != null) ...[
                        SizedBox(height: tokens.space.md),
                        SegmentedButton<StateBindingMode>(
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
                  ),
          ),
        ],
      ),
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
            label: const Text('SAVE'),
          ),
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
                prefixIcon: Icon(Icons.edit),
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
            SizedBox(height: tokens.space.xxl),

            // Actions section
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: tokens.radius.brMd,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.space.lg),
                    color: Theme.of(context).colorScheme.primary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Actions (${_actions.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _navigateToActionEditor(null, -1),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Action'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_actions.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(tokens.space.xxl),
                      child: Center(
                        child: Text(
                          'No actions yet. Add your first action by clicking the button above.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: tokens.color.textMuted),
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _actions.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _actions.removeAt(oldIndex);
                          _actions.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final action = _actions[index];
                        return Card(
                          key: ValueKey(action.id),
                          margin: EdgeInsets.symmetric(
                            horizontal: tokens.space.sm,
                            vertical: tokens.space.xs,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              child: Icon(_getActionTypeIcon(action.type)),
                            ),
                            title: Text(
                              _getActionTypeString(action.type),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(_getActionDescription(action)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: tokens.icon.lg),
                                  onPressed:
                                      () => _navigateToActionEditor(
                                        action,
                                        index,
                                      ),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon:
                                      Icon(Icons.delete, size: tokens.icon.lg),
                                  onPressed: () => _deleteAction(index),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                            onTap: () => _navigateToActionEditor(action, index),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            SizedBox(height: tokens.space.xxl),

            // Live tile section (plugin-driven dynamic title/icon)
            _buildLiveTileSection(),
            SizedBox(height: tokens.space.xxl),

            // Button appearance section
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: tokens.radius.brMd,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(tokens.space.lg),
                    color: Theme.of(context).colorScheme.primary,
                    child: Text(
                      'Button Appearance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(tokens.space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Button preview
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _hexToColor(_selectedColor),
                              borderRadius: tokens.radius.brLg,
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.color.shadow,
                                  blurRadius: tokens.space.sm,
                                  spreadRadius: tokens.border.hairline,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconData(_selectedIcon),
                                  size: tokens.space.huge,
                                  color: Colors.white,
                                ),
                                SizedBox(height: tokens.space.sm),
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Button Name'
                                      : _nameController.text,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: tokens.space.xxl),

                        // Color selection
                        Text(
                          'Button Color',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: tokens.space.sm),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _presetColors.length,
                            itemBuilder: (context, index) {
                              final color = _presetColors[index];
                              final colorHex = _colorToHex(color);
                              final isSelected = colorHex == _selectedColor;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: tokens.space.sm,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedColor = colorHex;
                                    });
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border:
                                          isSelected
                                              ? Border.all(
                                                color: Colors.white,
                                                width: tokens.border.focus,
                                              )
                                              : null,
                                      boxShadow:
                                          isSelected
                                              ? [
                                                BoxShadow(
                                                  color: tokens.color.shadow,
                                                  blurRadius: tokens.space.xs,
                                                  spreadRadius:
                                                      tokens.border.hairline,
                                                ),
                                              ]
                                              : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: tokens.space.xxl),

                        // Icon selection
                        Text(
                          'Button Icon',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: tokens.space.sm),
                        TextButton.icon(
                          onPressed: _showExtendedIconPicker,
                          icon: const Icon(Icons.search),
                          label: const Text('Browse Icons'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.space.lg,
                              vertical: tokens.space.sm,
                            ),
                          ),
                        ),
                        SizedBox(height: tokens.space.sm),

                        // Icons grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                                  color:
                                      isSelected
                                          ? _hexToColor(_selectedColor)
                                          : tokens.color.surfaceSubtle,
                                  borderRadius: tokens.radius.brSm,
                                ),
                                child: Icon(
                                  icon,
                                  size: tokens.icon.xl,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : tokens.color.textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
