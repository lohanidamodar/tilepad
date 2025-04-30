import 'package:uuid/uuid.dart';

/// Defines the types of actions a button can perform
enum ButtonType {
  /// Execute a custom shell command
  command,

  /// Execute a predefined command from the list
  commandPreset,

  /// Send keystroke(s) to the system
  keystroke,
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

  /// Type of action this button performs
  ButtonType type;

  /// Command to execute when the button is pressed (for command type)
  String command;

  /// Key to press (for keystroke type)
  String key;

  /// Modifier keys to hold while pressing the key (for keystroke type)
  /// Can include: ctrl, alt, shift, meta/win
  List<String> modifiers;

  /// Background color of the button (in hex format)
  String color;

  /// Creates a new button with the given properties
  Button({
    String? id,
    required this.name,
    required this.iconName,
    this.type = ButtonType.command,
    this.command = '',
    this.key = '',
    this.modifiers = const [],
    this.color = '#4285F4', // Default Google blue
  }) : id = id ?? const Uuid().v4();

  /// Creates a button from a JSON map
  factory Button.fromJson(Map<String, dynamic> json) {
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

  /// Converts this button to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'type': type.name,
      'command': command,
      'key': key,
      'modifiers': modifiers,
      'color': color,
    };
  }
}
