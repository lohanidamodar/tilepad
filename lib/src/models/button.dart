import 'package:uuid/uuid.dart';

/// Represents a custom button that can be displayed on the client
/// and configured from the server.
class Button {
  /// Unique identifier for the button
  final String id;

  /// Display name of the button
  String name;

  /// Icon identifier (corresponds to an icon in the Flutter library)
  String iconName;

  /// Command to execute when the button is pressed
  String command;

  /// Background color of the button (in hex format)
  String color;

  /// Creates a new button with the given properties
  Button({
    String? id,
    required this.name,
    required this.iconName,
    required this.command,
    this.color = '#4285F4', // Default Google blue
  }) : id = id ?? const Uuid().v4();

  /// Creates a button from a JSON map
  factory Button.fromJson(Map<String, dynamic> json) {
    return Button(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      command: json['command'] as String,
      color: json['color'] as String? ?? '#4285F4',
    );
  }

  /// Converts this button to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'command': command,
      'color': color,
    };
  }
}
