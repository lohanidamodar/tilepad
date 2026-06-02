import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:picons/picons.dart';

import '../design/design.dart';
import '../models/button.dart';
import '../utils/icon_picker_dialog.dart';
import '../utils/macro_icons.dart';

/// Predefined command with name, description, and platform-specific implementation
class PredefinedCommand {
  /// Display name of the command
  final String name;

  /// Description of what the command does
  final String description;

  /// Map of platform-specific command implementations
  final Map<String, String> platformCommands;

  /// Icon to display for this command
  final IconData icon;

  /// Creates a new predefined command
  const PredefinedCommand({
    required this.name,
    required this.description,
    required this.platformCommands,
    required this.icon,
  });

  /// Gets the command for the current platform
  String getCommand() {
    if (Platform.isWindows && platformCommands.containsKey('windows')) {
      return platformCommands['windows']!;
    } else if (Platform.isMacOS && platformCommands.containsKey('macos')) {
      return platformCommands['macos']!;
    } else if (Platform.isLinux && platformCommands.containsKey('linux')) {
      return platformCommands['linux']!;
    }

    // Fallback to first available command
    return platformCommands.values.first;
  }
}

/// List of predefined commands for common actions
final List<PredefinedCommand> predefinedCommands = [
  PredefinedCommand(
    name: 'Sleep Computer',
    description: 'Put the computer to sleep mode',
    platformCommands: {
      'windows':
          '%windir%\\System32\\rundll32.exe powrprof.dll,SetSuspendState 0,1,0',
      'macos': 'pmset sleepnow',
      'linux': 'systemctl suspend',
    },
    icon: PiconsRegular.power,
  ),
  PredefinedCommand(
    name: 'Shutdown Computer',
    description: 'Shutdown the computer',
    platformCommands: {
      'windows': 'shutdown /s /t 0',
      'macos': 'sudo shutdown -h now',
      'linux': 'sudo shutdown -h now',
    },
    icon: PiconsRegular.power,
  ),
  PredefinedCommand(
    name: 'Restart Computer',
    description: 'Restart the computer',
    platformCommands: {
      'windows': 'shutdown /r /t 0',
      'macos': 'sudo shutdown -r now',
      'linux': 'sudo reboot',
    },
    icon: PiconsRegular.arrowsClockwise,
  ),
  PredefinedCommand(
    name: 'Lock Screen',
    description: 'Lock the computer screen',
    platformCommands: {
      'windows': 'rundll32.exe user32.dll,LockWorkStation',
      'macos': 'pmset displaysleepnow',
      'linux': 'xdg-screensaver lock',
    },
    icon: PiconsRegular.lock,
  ),
  PredefinedCommand(
    name: 'Copy Selection',
    description: 'Copy selected text',
    platformCommands: {
      'windows':
          'powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'^c\')"',
      'macos':
          'osascript -e \'tell application "System Events" to keystroke "c" using command down\'',
      'linux': 'xdotool key ctrl+c',
    },
    icon: PiconsRegular.copy,
  ),
  PredefinedCommand(
    name: 'Paste',
    description: 'Paste clipboard content',
    platformCommands: {
      'windows':
          'powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'^v\')"',
      'macos':
          'osascript -e \'tell application "System Events" to keystroke "v" using command down\'',
      'linux': 'xdotool key ctrl+v',
    },
    icon: PiconsRegular.clipboard,
  ),
  PredefinedCommand(
    name: 'Take Screenshot',
    description: 'Capture a screenshot',
    platformCommands: {
      'windows':
          'powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\'{PRTSC}\')"',
      'macos': 'screencapture -i ~/Desktop/screenshot.png',
      'linux': 'gnome-screenshot -i',
    },
    icon: PiconsRegular.camera,
  ),
  PredefinedCommand(
    name: 'Volume Up',
    description: 'Increase system volume',
    platformCommands: {
      'windows':
          'powershell -command "(new-object -com wscript.shell).SendKeys([char]175)"',
      'macos':
          'osascript -e "set volume output volume (output volume of (get volume settings) + 10) --100%"',
      'linux': 'pactl set-sink-volume @DEFAULT_SINK@ +10%',
    },
    icon: PiconsRegular.speakerHigh,
  ),
  PredefinedCommand(
    name: 'Volume Down',
    description: 'Decrease system volume',
    platformCommands: {
      'windows':
          'powershell -command "(new-object -com wscript.shell).SendKeys([char]174)"',
      'macos':
          'osascript -e "set volume output volume (output volume of (get volume settings) - 10) --100%"',
      'linux': 'pactl set-sink-volume @DEFAULT_SINK@ -10%',
    },
    icon: PiconsRegular.speakerLow,
  ),
  PredefinedCommand(
    name: 'Mute/Unmute',
    description: 'Toggle system audio mute',
    platformCommands: {
      'windows':
          'powershell -command "(new-object -com wscript.shell).SendKeys([char]173)"',
      'macos': 'osascript -e "set volume with output muted"',
      'linux': 'pactl set-sink-mute @DEFAULT_SINK@ toggle',
    },
    icon: PiconsRegular.speakerX,
  ),
];

/// Dialog for editing a macro button's properties
class ButtonEditorDialog extends StatefulWidget {
  /// The button to edit, null if creating a new button
  final Button? button;

  /// Creates a new button editor dialog
  const ButtonEditorDialog({super.key, this.button});

  @override
  State<ButtonEditorDialog> createState() => _ButtonEditorDialogState();
}

class _ButtonEditorDialogState extends State<ButtonEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = MacroIcons.defaultId;
  String _selectedColor = '#4285F4';

  // List of actions for this button
  List<ButtonAction> _actions = [];

  // Variables for the action being edited
  int _editingActionIndex = -1; // -1 means creating a new action
  final _commandController = TextEditingController();
  ActionType _selectedType = ActionType.command;
  String _selectedKey = 'a';
  final Set<String> _selectedModifiers = <String>{};

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

  // Common keys for keystroke selection
  final List<String> _commonKeys = [
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'f1',
    'f2',
    'f3',
    'f4',
    'f5',
    'f6',
    'f7',
    'f8',
    'f9',
    'f10',
    'f11',
    'f12',
    'enter',
    'tab',
    'space',
    'backspace',
    'delete',
    'esc',
    'up',
    'down',
    'left',
    'right',
    'home',
    'end',
    'pageup',
    'pagedown',
  ];

  // Modifier keys
  final List<ModifierKeyOption> _modifierKeys = [
    ModifierKeyOption(
      name: 'Ctrl',
      value: 'ctrl',
      icon: Icons.keyboard_control_key,
    ),
    ModifierKeyOption(
      name: 'Alt',
      value: 'alt',
      icon: Icons.keyboard_alt_outlined,
    ),
    ModifierKeyOption(
      name: 'Shift',
      value: 'shift',
      icon: Icons.keyboard_arrow_up,
    ),
    ModifierKeyOption(
      name: 'Win/Meta',
      value: 'meta',
      icon: Icons.window_outlined,
    ),
  ];

  // UI States
  bool _showActionEditor = false;

  @override
  void initState() {
    super.initState();

    // Initialize form with existing button data if editing
    if (widget.button != null) {
      _nameController.text = widget.button!.name;
      _selectedIcon = widget.button!.iconName;
      _selectedColor = widget.button!.color;

      // Copy actions
      _actions =
          widget.button!.actions
              .map(
                (action) => ButtonAction(
                  id: action.id,
                  type: action.type,
                  command: action.command,
                  key: action.key,
                  modifiers: List<String>.from(action.modifiers),
                ),
              )
              .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  /// Saves the button and returns it
  void _saveButton() {
    if (_formKey.currentState!.validate()) {
      if (_actions.isEmpty) {
        // Show error if no actions are defined
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please add at least one action to the button',
            ),
            backgroundColor: context.tokens.color.danger,
          ),
        );
        return;
      }

      final button = Button(
        id: widget.button?.id,
        name: _nameController.text,
        iconName: _selectedIcon,
        actions: _actions,
        color: _selectedColor,
      );

      Navigator.of(context).pop(button);
    }
  }

  /// Converts a color to a hex string
  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  /// Converts a hex string to a Color
  Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
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

  /// Creates a new action based on current form values
  ButtonAction _createActionFromForm() {
    return ButtonAction(
      type: _selectedType,
      command:
          _selectedType == ActionType.command ||
                  _selectedType == ActionType.commandPreset
              ? _commandController.text
              : '',
      key: _selectedType == ActionType.keystroke ? _selectedKey : '',
      modifiers:
          _selectedType == ActionType.keystroke
              ? List<String>.from(_selectedModifiers)
              : const [],
    );
  }

  /// Saves the current action being edited
  void _saveAction() {
    if (_commandController.text.isEmpty &&
        (_selectedType == ActionType.command ||
            _selectedType == ActionType.commandPreset)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a command'),
          backgroundColor: context.tokens.color.danger,
        ),
      );
      return;
    }

    final action = _createActionFromForm();

    setState(() {
      if (_editingActionIndex >= 0 && _editingActionIndex < _actions.length) {
        // Update existing action
        _actions[_editingActionIndex] = action;
      } else {
        // Add new action
        _actions.add(action);
      }

      // Reset UI and form
      _showActionEditor = false;
      _editingActionIndex = -1;
      _resetActionForm();
    });
  }

  /// Cancels the current action editing
  void _cancelActionEdit() {
    setState(() {
      _showActionEditor = false;
      _editingActionIndex = -1;
      _resetActionForm();
    });
  }

  /// Resets the action form to default values
  void _resetActionForm() {
    _commandController.text = '';
    _selectedType = ActionType.command;
    _selectedKey = 'a';
    _selectedModifiers.clear();
  }

  /// Starts editing an existing action
  void _editAction(int index) {
    final action = _actions[index];

    setState(() {
      _editingActionIndex = index;
      _selectedType = action.type;
      _commandController.text = action.command;
      _selectedKey = action.key.isEmpty ? 'a' : action.key;
      _selectedModifiers.clear();
      _selectedModifiers.addAll(action.modifiers);
      _showActionEditor = true;
    });
  }

  /// Starts adding a new action
  void _addAction() {
    setState(() {
      _editingActionIndex = -1;
      _resetActionForm();
      _showActionEditor = true;
    });
  }

  /// Deletes an action
  void _deleteAction(int index) {
    setState(() {
      _actions.removeAt(index);
    });
  }

  /// Moves an action up in the list
  void _moveActionUp(int index) {
    if (index <= 0) return;
    setState(() {
      final action = _actions.removeAt(index);
      _actions.insert(index - 1, action);
    });
  }

  /// Moves an action down in the list
  void _moveActionDown(int index) {
    if (index >= _actions.length - 1) return;
    setState(() {
      final action = _actions.removeAt(index);
      _actions.insert(index + 1, action);
    });
  }

  /// Gets a human-readable description of the keystroke
  String _getKeystrokeDescription() {
    final modifierNames = _selectedModifiers
        .map((m) {
          return _modifierKeys.firstWhere((mod) => mod.value == m).name;
        })
        .join(' + ');

    final keyName = _selectedKey.toUpperCase();

    return modifierNames.isNotEmpty ? '$modifierNames + $keyName' : keyName;
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

  /// Builds the action list section
  Widget _buildActionsList() {
    if (_showActionEditor) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Actions (${_actions.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ElevatedButton.icon(
              onPressed: _addAction,
              icon: const Icon(Icons.add),
              label: const Text('Add Action'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.tokens.space.lg,
                  vertical: context.tokens.space.sm,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.tokens.space.sm),
        if (_actions.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.tokens.space.lg),
              child: Text(
                'No actions defined yet. Add your first action.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.color.textMuted,
                    ),
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _actions.length,
              separatorBuilder: (context, index) =>
                  Divider(height: context.tokens.border.hairline),
              itemBuilder: (context, index) {
                final action = _actions[index];
                return ListTile(
                  title: Text(
                    _getActionTypeString(action.type),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(_getActionDescription(action)),
                  leading: Icon(_getActionTypeIcon(action.type)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_upward,
                          size: context.tokens.icon.lg,
                        ),
                        onPressed:
                            index > 0 ? () => _moveActionUp(index) : null,
                        tooltip: 'Move Up',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_downward,
                          size: context.tokens.icon.lg,
                        ),
                        onPressed:
                            index < _actions.length - 1
                                ? () => _moveActionDown(index)
                                : null,
                        tooltip: 'Move Down',
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: context.tokens.icon.lg),
                        onPressed: () => _editAction(index),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: context.tokens.icon.lg),
                        onPressed: () => _deleteAction(index),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        SizedBox(height: context.tokens.space.lg),
      ],
    );
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

  /// Builds the action editor section
  Widget _buildActionEditor() {
    if (!_showActionEditor) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _editingActionIndex >= 0 ? 'Edit Action' : 'Add New Action',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _cancelActionEdit,
                  child: const Text('Cancel'),
                ),
                SizedBox(width: context.tokens.space.sm),
                ElevatedButton(
                  onPressed: _saveAction,
                  child: const Text('Save Action'),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: context.tokens.space.lg),

        // Action type selection
        Text('Action Type', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: context.tokens.space.sm),
        SegmentedButton<ActionType>(
          segments: const [
            ButtonSegment<ActionType>(
              value: ActionType.command,
              label: Text('Custom'),
              icon: Icon(Icons.terminal),
            ),
            ButtonSegment<ActionType>(
              value: ActionType.commandPreset,
              label: Text('Preset'),
              icon: Icon(Icons.list_alt),
            ),
            ButtonSegment<ActionType>(
              value: ActionType.keystroke,
              label: Text('Keystroke'),
              icon: Icon(Icons.keyboard),
            ),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<ActionType> newSelection) {
            setState(() {
              _selectedType = newSelection.first;
            });
          },
        ),
        SizedBox(height: context.tokens.space.lg),

        // Custom command section
        if (_selectedType == ActionType.command)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _commandController,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'e.g., notepad.exe or python script.py',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: context.tokens.space.lg),
            ],
          ),

        // Predefined command section
        if (_selectedType == ActionType.commandPreset)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predefined Commands',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: context.tokens.space.sm),
              Wrap(
                spacing: context.tokens.space.sm,
                runSpacing: context.tokens.space.sm,
                children:
                    predefinedCommands.map((command) {
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(command.icon, size: context.tokens.icon.sm),
                            SizedBox(width: context.tokens.space.xs),
                            Text(command.name),
                          ],
                        ),
                        selected:
                            _commandController.text == command.getCommand(),
                        onSelected: (selected) {
                          setState(() {
                            _commandController.text = command.getCommand();
                          });
                        },
                      );
                    }).toList(),
              ),
              SizedBox(height: context.tokens.space.lg),
            ],
          ),

        // Keystroke section
        if (_selectedType == ActionType.keystroke)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Keystroke',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: context.tokens.space.sm),

              // Modifiers selection
              Wrap(
                spacing: context.tokens.space.sm,
                runSpacing: context.tokens.space.sm,
                children:
                    _modifierKeys.map((modifier) {
                      final isSelected = _selectedModifiers.contains(
                        modifier.value,
                      );
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              modifier.icon,
                              size: context.tokens.icon.sm,
                              color: isSelected
                                  ? context.tokens.color.onAccent
                                  : null,
                            ),
                            SizedBox(width: context.tokens.space.xs),
                            Text(modifier.name),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedModifiers.add(modifier.value);
                            } else {
                              _selectedModifiers.remove(modifier.value);
                            }
                          });
                        },
                        backgroundColor: context.tokens.color.surfaceSubtle,
                        selectedColor: _hexToColor(_selectedColor),
                        checkmarkColor: context.tokens.color.onAccent,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? context.tokens.color.onAccent
                              : null,
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: context.tokens.space.lg),

              // Key selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Key',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedKey,
                items:
                    _commonKeys.map((key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(key.toUpperCase()),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedKey = value;
                    });
                  }
                },
              ),
              SizedBox(height: context.tokens.space.sm),
              Text(
                'This will simulate pressing ${_getKeystrokeDescription()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),

        SizedBox(height: context.tokens.space.lg),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(context.tokens.space.lg),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.button == null ? 'Create Button' : 'Edit Button',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: context.tokens.space.lg),

              // Use Expanded + ListView instead of Column for better scrolling
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Button Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.tokens.space.lg),

                    // Actions list and editor
                    _buildActionsList(),
                    _buildActionEditor(),

                    Text(
                      'Button Color',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: context.tokens.space.sm),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetColors.length,
                        itemBuilder: (context, index) {
                          final color = _presetColors[index];
                          final colorHex = _colorToHex(color);
                          final isSelected = colorHex == _selectedColor;

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.tokens.space.sm,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = colorHex;
                                });
                              },
                              child: Container(
                                width: context.tokens.icon.xl +
                                    context.tokens.space.lg,
                                height: context.tokens.icon.xl +
                                    context.tokens.space.lg,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border:
                                      isSelected
                                          ? Border.all(
                                            color: context
                                                .tokens.color.surface,
                                            width: context.tokens.border.focus,
                                          )
                                          : null,
                                  boxShadow:
                                      isSelected
                                          ? context.tokens.shadowSm
                                          : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: context.tokens.space.lg),
                    Text(
                      'Button Icon',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: context.tokens.space.sm),

                    // More icons button
                    Center(
                      child: Column(
                        children: [
                          // Selected icon preview
                          Container(
                            width: context.tokens.space.huge +
                                context.tokens.space.md,
                            height: context.tokens.space.huge +
                                context.tokens.space.md,
                            decoration: BoxDecoration(
                              color: _hexToColor(_selectedColor),
                              borderRadius: context.tokens.radius.brSm,
                            ),
                            child: Icon(
                              _getIconData(_selectedIcon),
                              color: context.tokens.color.onAccent,
                              size: context.tokens.space.xxxl +
                                  context.tokens.space.xs,
                            ),
                          ),
                          SizedBox(height: context.tokens.space.sm),
                          TextButton.icon(
                            onPressed: _showExtendedIconPicker,
                            icon: const Icon(Icons.search),
                            label: const Text('More Icons'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.tokens.space.lg,
                                vertical: context.tokens.space.sm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.tokens.space.sm),

                    // Icons grid
                    GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: context.tokens.space.xs,
                            crossAxisSpacing: context.tokens.space.xs,
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
                          borderRadius: context.tokens.radius.brSm,
                          child: Container(
                            margin: EdgeInsets.all(context.tokens.space.xs),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? _hexToColor(_selectedColor)
                                      : context.tokens.color.surfaceSubtle,
                              borderRadius: context.tokens.radius.brSm,
                            ),
                            child: Icon(
                              icon,
                              size: context.tokens.icon.xl,
                              color: isSelected
                                  ? context.tokens.color.onAccent
                                  : context.tokens.color.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom buttons
              SizedBox(height: context.tokens.space.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: context.tokens.space.lg),
                  ElevatedButton(
                    onPressed: _saveButton,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves a stored icon identifier to its Phosphor [IconData].
  IconData _getIconData(String iconName) => MacroIcons.resolve(iconName);
}

/// Helper class for modifier key options
class ModifierKeyOption {
  /// Display name of the modifier key
  final String name;

  /// Value to be stored
  final String value;

  /// Icon to represent the modifier key
  final IconData icon;

  /// Creates a new modifier key option
  const ModifierKeyOption({
    required this.name,
    required this.value,
    required this.icon,
  });
}
