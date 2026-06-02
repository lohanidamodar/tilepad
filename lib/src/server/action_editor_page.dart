// filepath: g:\dev\projects\macro-deck\lib\src\server\action_editor_page.dart
import 'package:flutter/material.dart';
import 'package:picons/picons.dart';
import 'dart:io' show Platform;

import '../design/design.dart';
import '../models/button.dart';
import 'plugins/plugin_manifest.dart';
import 'plugins_screen.dart' show PluginFieldInput;
import 'server.dart';

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

  /// The server, used to list plugin actions and fetch dynamic option lists.
  final MarcoServer server;

  /// Creates a new action editor page
  const ActionEditorPage({super.key, this.action, required this.server});

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

  // Plugin action properties
  String? _pluginId;
  String? _pluginActionId;
  final Map<String, dynamic> _pluginSettings = <String, dynamic>{};

  /// Cached dynamic option lists, keyed by the list id.
  final Map<String, List<PluginFieldOption>> _dynamicOptions = {};

  // Common keys for keystroke selection. Named keys come first so they're
  // easy to find without scrolling past the whole alphabet.
  final List<String> _commonKeys = [
    'enter',
    'tab',
    'space',
    'esc',
    'backspace',
    'delete',
    'up',
    'down',
    'left',
    'right',
    'home',
    'end',
    'pageup',
    'pagedown',
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

      if (widget.action!.type == ActionType.plugin) {
        _pluginId = widget.action!.pluginId.isEmpty
            ? null
            : widget.action!.pluginId;
        _pluginActionId = widget.action!.pluginActionId.isEmpty
            ? null
            : widget.action!.pluginActionId;
        _pluginSettings.addAll(widget.action!.settings);
        _prefetchDynamicLists();
      }
    }
  }

  /// The manifest of the currently selected plugin, if any.
  PluginManifest? get _selectedPluginManifest {
    if (_pluginId == null) return null;
    for (final plugin in widget.server.plugins) {
      if (plugin.manifest.id == _pluginId) return plugin.manifest;
    }
    return null;
  }

  /// The currently selected plugin action definition, if any.
  PluginActionDef? get _selectedPluginAction {
    final manifest = _selectedPluginManifest;
    if (manifest == null || _pluginActionId == null) return null;
    return manifest.action(_pluginActionId!);
  }

  /// Fetches options for every dynamic `select` field of the chosen action.
  Future<void> _prefetchDynamicLists() async {
    final action = _selectedPluginAction;
    final pluginId = _pluginId;
    final actionId = _pluginActionId;
    if (action == null || pluginId == null) return;
    for (final field in action.fields) {
      final listId = field.optionsFrom;
      if (field.type == PluginFieldType.select && listId != null) {
        // Pass the current field values so plugins can compute dependent lists.
        final options = await widget.server.requestPluginList(
          pluginId,
          listId,
          fields: Map<String, dynamic>.from(_pluginSettings),
        );
        // Discard if the user switched plugin/action while we were awaiting.
        if (!mounted || _pluginId != pluginId || _pluginActionId != actionId) {
          return;
        }
        setState(() => _dynamicOptions[listId] = options);
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
          SnackBar(
            content: const Text('Please enter a command'),
            backgroundColor: context.tokens.color.danger,
          ),
        );
        return;
      }

      if (_selectedType == ActionType.plugin &&
          (_pluginId == null || _pluginActionId == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please choose a plugin and an action'),
            backgroundColor: context.tokens.color.danger,
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
        pluginId: _selectedType == ActionType.plugin ? (_pluginId ?? '') : '',
        pluginActionId:
            _selectedType == ActionType.plugin ? (_pluginActionId ?? '') : '',
        settings: _selectedType == ActionType.plugin
            ? Map<String, dynamic>.from(_pluginSettings)
            : const {},
      );

      Navigator.of(context).pop(action);
    }
  }

  /// Short label for an action type (used by the type chips).
  String _typeLabel(ActionType type) {
    switch (type) {
      case ActionType.command:
        return 'Custom';
      case ActionType.commandPreset:
        return 'Preset';
      case ActionType.keystroke:
        return 'Keystroke';
      case ActionType.promptText:
        return 'Prompt Text';
      case ActionType.promptKeystroke:
        return 'Prompt Keys';
      case ActionType.selectWindow:
        return 'Select Window';
      case ActionType.plugin:
        return 'Plugin';
    }
  }

  /// Icon for an action type (used by the type chips).
  IconData _typeIcon(ActionType type) {
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

  /// Builds an explanatory card for the dynamic "prompt" action types.
  Widget _buildPromptInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.brMd),
      child: Padding(
        padding: EdgeInsets.all(tokens.space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            SizedBox(width: tokens.space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: tokens.space.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
          padding: EdgeInsets.all(context.tokens.space.lg),
          children: [
            // Action type selection
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: context.tokens.radius.brMd,
              ),
              child: Padding(
                padding: EdgeInsets.all(context.tokens.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.tokens.space.lg),
                    Wrap(
                      spacing: context.tokens.space.sm,
                      runSpacing: context.tokens.space.sm,
                      children:
                          ActionType.values.map((type) {
                            final selected = _selectedType == type;
                            return ChoiceChip(
                              avatar: Icon(
                                _typeIcon(type),
                                size: context.tokens.icon.md,
                                color:
                                    selected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer
                                        : null,
                              ),
                              label: Text(_typeLabel(type)),
                              selected: selected,
                              onSelected:
                                  (_) =>
                                      setState(() => _selectedType = type),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.tokens.space.lg),

            // Command section
            if (_selectedType == ActionType.command)
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: context.tokens.radius.brMd,
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Command',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: context.tokens.space.lg),
                      Text(
                        'Enter the command to execute when this action is triggered:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.tokens.color.textSecondary,
                            ),
                      ),
                      SizedBox(height: context.tokens.space.sm),
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
                      SizedBox(height: context.tokens.space.lg),
                      Text(
                        'Tips:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: context.tokens.space.xs),
                      Text(
                        '• Use full paths for programs not in the system PATH\n'
                        '• For PowerShell commands, start with "powershell -command"\n'
                        '• For multiple commands, use && between commands',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.tokens.color.textSecondary,
                            ),
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
                  borderRadius: context.tokens.radius.brMd,
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preset Commands',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: context.tokens.space.lg),
                      Text(
                        'Select from common predefined commands:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.tokens.color.textSecondary,
                            ),
                      ),
                      SizedBox(height: context.tokens.space.lg),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 3,
                              crossAxisSpacing: context.tokens.space.sm,
                              mainAxisSpacing: context.tokens.space.sm,
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
                            borderRadius: context.tokens.radius.brSm,
                            elevation: 0,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _commandController.text =
                                      command.getCommand();
                                });
                              },
                              borderRadius: context.tokens.radius.brSm,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: context.tokens.space.sm,
                                  horizontal: context.tokens.space.md,
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
                                              : context
                                                  .tokens.color.textMuted,
                                    ),
                                    SizedBox(width: context.tokens.space.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            command.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color: context
                                                      .tokens.color.textMuted,
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
                                        size: context.tokens.icon.sm,
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
                  borderRadius: context.tokens.radius.brMd,
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keystroke',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: context.tokens.space.lg),

                      // Keystroke preview
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: context.tokens.space.lg,
                          horizontal: context.tokens.space.xxl,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: context.tokens.radius.brSm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard),
                            SizedBox(width: context.tokens.space.lg),
                            Text(
                              _getKeystrokeDescription(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.tokens.space.xxl),

                      // Modifier keys
                      Text(
                        'Modifier Keys',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: context.tokens.space.sm),
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
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
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
                      SizedBox(height: context.tokens.space.xxl),

                      // Key selection
                      Text(
                        'Key',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: context.tokens.space.sm),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: context.tokens.space.lg,
                            vertical: context.tokens.space.lg,
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

            // Prompt-for-text info
            if (_selectedType == ActionType.promptText)
              _buildPromptInfoCard(
                icon: Icons.keyboard_alt_outlined,
                title: 'Prompt for Text',
                description:
                    'When this button is pressed, the device asks for text to '
                    'send and the server types it into the active app.',
              ),

            // Prompt-for-key-combo info
            if (_selectedType == ActionType.promptKeystroke)
              _buildPromptInfoCard(
                icon: Icons.touch_app_outlined,
                title: 'Prompt for Key Combo',
                description:
                    'When this button is pressed, the device asks for a key '
                    'combination (modifiers + key) and the server sends it.',
              ),

            // Select-window info
            if (_selectedType == ActionType.selectWindow)
              _buildPromptInfoCard(
                icon: Icons.web_asset,
                title: 'Select Window',
                description:
                    'When this button is pressed, the device shows the '
                    'server\'s open windows and brings the chosen one to front.',
              ),

            if (_selectedType == ActionType.plugin) _buildPluginSection(),
          ],
        ),
      ),
    );
  }

  /// Builds the plugin action picker and its native settings fields.
  Widget _buildPluginSection() {
    final plugins = widget.server.plugins;
    if (plugins.isEmpty) {
      return _buildPromptInfoCard(
        icon: Icons.extension_off_outlined,
        title: 'No plugins installed',
        description:
            'Install and enable a plugin from the Plugins screen to use '
            'plugin actions here.',
      );
    }

    final manifest = _selectedPluginManifest;
    final action = _selectedPluginAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _pluginId,
          decoration: const InputDecoration(
            labelText: 'Plugin',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final plugin in plugins)
              DropdownMenuItem(
                value: plugin.manifest.id,
                child: Text(plugin.manifest.name),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _pluginId = value;
              _pluginActionId = null;
              _pluginSettings.clear();
              _dynamicOptions.clear();
            });
          },
        ),
        SizedBox(height: context.tokens.space.lg),
        if (manifest != null)
          DropdownButtonFormField<String>(
            initialValue: _pluginActionId,
            decoration: const InputDecoration(
              labelText: 'Action',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in manifest.actions)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (value) {
              setState(() {
                _pluginActionId = value;
                _pluginSettings.clear();
                _dynamicOptions.clear();
              });
              _prefetchDynamicLists();
            },
          ),
        if (action != null && action.fields.isNotEmpty) ...[
          SizedBox(height: context.tokens.space.lg),
          for (final field in action.fields)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.tokens.space.xs),
              child: PluginFieldInput(
                field: field,
                value: _pluginSettings[field.key] ?? field.defaultValue,
                dynamicOptions: field.optionsFrom != null
                    ? (_dynamicOptions[field.optionsFrom] ?? const [])
                    : const [],
                onChanged: (v) =>
                    setState(() => _pluginSettings[field.key] = v),
              ),
            ),
        ],
      ],
    );
  }
}
