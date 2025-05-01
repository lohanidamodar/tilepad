import 'package:uuid/uuid.dart';

/// Defines the types of actions a button can perform
enum ActionType {
  /// Execute a custom shell command
  command,

  /// Execute a predefined command from the list
  commandPreset,

  /// Send keystroke(s) to the system
  keystroke,
}

/// Represents a single action that can be performed by a button
class ButtonAction {
  /// Unique identifier for the action
  final String id;

  /// Type of this action
  ActionType type;

  /// Command to execute (for command and commandPreset types)
  String command;

  /// Key to press (for keystroke type)
  String key;

  /// Modifier keys to hold while pressing the key (for keystroke type)
  /// Can include: ctrl, alt, shift, meta/win
  List<String> modifiers;

  /// Creates a new button action with the given properties
  ButtonAction({
    String? id,
    required this.type,
    this.command = '',
    this.key = '',
    this.modifiers = const [],
  }) : id = id ?? const Uuid().v4();

  /// Creates a button action from a JSON map
  factory ButtonAction.fromJson(Map<String, dynamic> json) {
    return ButtonAction(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: ActionType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => ActionType.command,
      ),
      command: json['command'] as String? ?? '',
      key: json['key'] as String? ?? '',
      modifiers:
          (json['modifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Converts this action to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'command': command,
      'key': key,
      'modifiers': modifiers,
    };
  }
}

/// Represents a custom button that can be displayed on the client
/// and configured from the server.
class Button {
  /// Unique identifier for the button
  final String id;

  /// Display name of the button
  String name;

  /// Icon identifier (corresponds to an icon in the Flutter library)
  String iconName;

  /// List of actions to perform when the button is pressed
  List<ButtonAction> actions;

  /// Background color of the button (in hex format)
  String color;

  // The following properties are kept for backward compatibility
  // and convenience when dealing with a single action

  /// Type of action this button performs (for backward compatibility)
  ButtonType get type =>
      actions.isNotEmpty
          ? _convertActionType(actions.first.type)
          : ButtonType.command;

  /// Command to execute when the button is pressed (for backward compatibility)
  String get command => actions.isNotEmpty ? actions.first.command : '';

  /// Key to press (for backward compatibility)
  String get key => actions.isNotEmpty ? actions.first.key : '';

  /// Modifier keys to hold while pressing the key (for backward compatibility)
  List<String> get modifiers =>
      actions.isNotEmpty ? actions.first.modifiers : const [];

  /// Creates a new button with the given properties
  Button({
    String? id,
    required this.name,
    required this.iconName,
    List<ButtonAction>? actions,
    ButtonType? type,
    String command = '',
    String key = '',
    List<String> modifiers = const [],
    this.color = '#4285F4', // Default Google blue
  }) : id = id ?? const Uuid().v4(),
       actions = actions ?? [] {
    // If actions weren't provided but type was, create a legacy-style action
    if (this.actions.isEmpty && type != null) {
      this.actions.add(
        ButtonAction(
          type: _convertButtonType(type),
          command: command,
          key: key,
          modifiers: modifiers,
        ),
      );
    }
  }

  /// Creates a button from a JSON map
  factory Button.fromJson(Map<String, dynamic> json) {
    // Check if the JSON has the new actions array
    final actionsList = json['actions'] as List<dynamic>?;

    if (actionsList != null) {
      // New format with multiple actions
      return Button(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String,
        actions:
            actionsList
                .map(
                  (actionJson) =>
                      ButtonAction.fromJson(actionJson as Map<String, dynamic>),
                )
                .toList(),
        color: json['color'] as String? ?? '#4285F4',
      );
    } else {
      // Legacy format with a single action
      return Button(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String,
        type: ButtonType.values.firstWhere(
          (e) => e.name == (json['type'] as String?),
          orElse: () => ButtonType.command,
        ),
        command: json['command'] as String? ?? '',
        key: json['key'] as String? ?? '',
        modifiers:
            (json['modifiers'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        color: json['color'] as String? ?? '#4285F4',
      );
    }
  }

  /// Converts this button to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'actions': actions.map((action) => action.toJson()).toList(),
      'color': color,
    };
  }

  /// Helper method to convert ActionType to ButtonType
  ButtonType _convertActionType(ActionType actionType) {
    switch (actionType) {
      case ActionType.command:
        return ButtonType.command;
      case ActionType.commandPreset:
        return ButtonType.commandPreset;
      case ActionType.keystroke:
        return ButtonType.keystroke;
    }
  }

  /// Helper method to convert ButtonType to ActionType
  ActionType _convertButtonType(ButtonType buttonType) {
    switch (buttonType) {
      case ButtonType.command:
        return ActionType.command;
      case ButtonType.commandPreset:
        return ActionType.commandPreset;
      case ButtonType.keystroke:
        return ActionType.keystroke;
    }
  }
}

/// Represents a page of buttons for organization
class Page {
  /// Unique identifier for the page
  final String id;

  /// Display name of the page
  String name;

  /// Order of the page (for sorting)
  int order;

  /// List of buttons on this page
  List<Button> buttons;

  /// Creates a new page with the given properties
  Page({String? id, required this.name, this.order = 0, List<Button>? buttons})
    : id = id ?? const Uuid().v4(),
      buttons = buttons ?? [];

  /// Creates a page from a JSON map
  factory Page.fromJson(Map<String, dynamic> json) {
    final buttonsList = json['buttons'] as List<dynamic>?;

    return Page(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled',
      order: json['order'] as int? ?? 0,
      buttons:
          buttonsList != null
              ? buttonsList
                  .map(
                    (buttonJson) =>
                        Button.fromJson(buttonJson as Map<String, dynamic>),
                  )
                  .toList()
              : [],
    );
  }

  /// Converts this page to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'buttons': buttons.map((button) => button.toJson()).toList(),
    };
  }
}

/// Legacy enum type - kept for backward compatibility
enum ButtonType {
  /// Execute a custom shell command
  command,

  /// Execute a predefined command from the list
  commandPreset,

  /// Send keystroke(s) to the system
  keystroke,
}
