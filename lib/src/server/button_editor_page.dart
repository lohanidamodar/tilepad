// filepath: g:\dev\projects\macro-deck\lib\src\server\button_editor_page.dart
import 'package:flutter/material.dart';
import '../utils/macro_icons.dart';

import '../models/button.dart';
import '../utils/icon_picker_dialog.dart';
import 'action_editor_page.dart';
import 'server.dart';

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
          const SnackBar(
            content: Text('Please add at least one action to the button'),
            backgroundColor: Colors.red,
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    // Gather all states exposed by installed plugins.
    final states = <_StateOption>[];
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
    final currentKey = _stateBinding == null
        ? null
        : '${_stateBinding!.pluginId}|${_stateBinding!.stateId}';
    final hasMatch = states.any((s) => s.key == currentKey);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: theme.colorScheme.primary,
            child: Text(
              'Live Tile (optional)',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: states.isEmpty
                ? Text(
                    'Install and enable a plugin that exposes live states to '
                    'drive this button with live data.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show a live value from a plugin on this button.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 24),

            // Actions section
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Theme.of(context).colorScheme.primary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Actions (${_actions.length})',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No actions yet. Add your first action by clicking the button above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
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
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_getActionDescription(action)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed:
                                      () => _navigateToActionEditor(
                                        action,
                                        index,
                                      ),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
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
            const SizedBox(height: 24),

            // Live tile section (plugin-driven dynamic title/icon)
            _buildLiveTileSection(),
            const SizedBox(height: 24),

            // Button appearance section
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Theme.of(context).colorScheme.primary,
                    child: Text(
                      'Button Appearance',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
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
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconData(_selectedIcon),
                                  size: 50,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Button Name'
                                      : _nameController.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Color selection
                        Text(
                          'Button Color',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
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
                                                width: 3,
                                              )
                                              : null,
                                      boxShadow:
                                          isSelected
                                              ? [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(
                                                    50,
                                                  ),
                                                  blurRadius: 5,
                                                  spreadRadius: 1,
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
                        const SizedBox(height: 24),

                        // Icon selection
                        Text(
                          'Button Icon',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showExtendedIconPicker,
                          icon: const Icon(Icons.search),
                          label: const Text('Browse Icons'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Icons grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
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
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? _hexToColor(_selectedColor)
                                          : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  size: 24,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black87,
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
