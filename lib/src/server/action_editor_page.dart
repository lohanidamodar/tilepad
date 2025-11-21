// filepath: g:\dev\projects\macro-deck\lib\src\server\action_editor_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io' show Platform;

import '../models/button.dart';

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
    icon: FontAwesomeIcons.powerOff,
  ),
  PredefinedCommand(
    name: 'Shutdown Computer',
    description: 'Shutdown the computer',
    platformCommands: {
      'windows': 'shutdown /s /t 0',
      'macos': 'sudo shutdown -h now',
      'linux': 'sudo shutdown -h now',
    },
    icon: FontAwesomeIcons.powerOff,
  ),
  PredefinedCommand(
    name: 'Restart Computer',
    description: 'Restart the computer',
    platformCommands: {
      'windows': 'shutdown /r /t 0',
      'macos': 'sudo shutdown -r now',
      'linux': 'sudo reboot',
    },
    icon: FontAwesomeIcons.arrowsRotate,
  ),
  PredefinedCommand(
    name: 'Lock Screen',
    description: 'Lock the computer screen',
    platformCommands: {
      'windows': 'rundll32.exe user32.dll,LockWorkStation',
      'macos': 'pmset displaysleepnow',
      'linux': 'xdg-screensaver lock',
    },
    icon: FontAwesomeIcons.lock,
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
    icon: FontAwesomeIcons.copy,
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
    icon: FontAwesomeIcons.paste,
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
    icon: FontAwesomeIcons.camera,
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
    icon: FontAwesomeIcons.volumeHigh,
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
    icon: FontAwesomeIcons.volumeLow,
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
    icon: FontAwesomeIcons.volumeXmark,
  ),
];

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

/// Page for editing a button action
class ActionEditorPage extends StatefulWidget {
  /// The action to edit, null if creating a new action
  final ButtonAction? action;

  /// Creates a new action editor page
  const ActionEditorPage({super.key, this.action});

  @override
  State<ActionEditorPage> createState() => _ActionEditorPageState();
}

class _ActionEditorPageState extends State<ActionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _commandController = TextEditingController();

  // Action properties
  ActionType _selectedType = ActionType.command;
  String _selectedKey = 'a';
  final Set<String> _selectedModifiers = <String>{};

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

  @override
  void initState() {
    super.initState();

    // Initialize form with existing action data if editing
    if (widget.action != null) {
      _selectedType = widget.action!.type;
      _commandController.text = widget.action!.command;

      if (widget.action!.key.isNotEmpty) {
        _selectedKey = widget.action!.key;
      }

      if (widget.action!.modifiers.isNotEmpty) {
        _selectedModifiers.addAll(widget.action!.modifiers);
      }
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  /// Saves the action and returns it
  void _saveAction() {
    if (_formKey.currentState!.validate()) {
      if ((_selectedType == ActionType.command ||
              _selectedType == ActionType.commandPreset) &&
          _commandController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a command'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final action = ButtonAction(
        id: widget.action?.id,
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

      Navigator.of(context).pop(action);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.action == null ? 'Add Action' : 'Edit Action'),
        actions: [
          TextButton.icon(
            onPressed: _saveAction,
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
            // Action type selection
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<ActionType>(
                      segments: [
                        ButtonSegment<ActionType>(
                          value: ActionType.command,
                          label: const Text('Custom'),
                          icon: const Icon(Icons.terminal),
                        ),
                        ButtonSegment<ActionType>(
                          value: ActionType.commandPreset,
                          label: const Text('Preset'),
                          icon: const Icon(Icons.list_alt),
                        ),
                        ButtonSegment<ActionType>(
                          value: ActionType.keystroke,
                          label: const Text('Keystroke'),
                          icon: const Icon(Icons.keyboard),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (Set<ActionType> newSelection) {
                        setState(() {
                          _selectedType = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Command section
            if (_selectedType == ActionType.command)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Command',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Enter the command to execute when this action is triggered:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _commandController,
                        decoration: const InputDecoration(
                          labelText: 'Command',
                          hintText: 'e.g., notepad.exe or python script.py',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                        minLines: 1,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a command';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tips:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Use full paths for programs not in the system PATH\n'
                        '• For PowerShell commands, start with "powershell -command"\n'
                        '• For multiple commands, use && between commands',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Preset command section
            if (_selectedType == ActionType.commandPreset)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preset Commands',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select from common predefined commands:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: predefinedCommands.length,
                        itemBuilder: (context, index) {
                          final command = predefinedCommands[index];
                          final isSelected =
                              _commandController.text == command.getCommand();

                          return Material(
                            color:
                                isSelected
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            elevation: isSelected ? 3 : 1,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _commandController.text =
                                      command.getCommand();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                  horizontal: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      command.icon,
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            command.name,
                                            style: TextStyle(
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              color:
                                                  isSelected
                                                      ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                      : null,
                                            ),
                                          ),
                                          Text(
                                            command.description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 16,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Keystroke section
            if (_selectedType == ActionType.keystroke)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keystroke',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Keystroke preview
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard),
                            const SizedBox(width: 16),
                            Text(
                              _getKeystrokeDescription(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Modifier keys
                      Text(
                        'Modifier Keys',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                                      size: 16,
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                              : null,
                                    ),
                                    const SizedBox(width: 4),
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                selectedColor:
                                    Theme.of(context).colorScheme.primary,
                                checkmarkColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                showCheckmark: true,
                                labelStyle: TextStyle(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                          : null,
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Key selection
                      Text(
                        'Key',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        initialValue: _selectedKey,
                        isExpanded: true,
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
