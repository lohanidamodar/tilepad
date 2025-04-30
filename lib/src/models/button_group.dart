import 'button.dart';

/// Represents a group of related buttons
class ButtonGroup {
  /// Unique ID of the group
  final String? id;

  /// Name of the group
  final String name;

  /// Color of the group (as hex string)
  final String color;

  /// List of buttons in this group
  final List<Button> buttons;

  /// Creates a new button group
  const ButtonGroup({
    this.id,
    required this.name,
    required this.color,
    this.buttons = const [],
  });

  /// Converts the group to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'buttons': buttons.map((button) => button.toJson()).toList(),
    };
  }

  /// Creates a group from a JSON object
  factory ButtonGroup.fromJson(Map<String, dynamic> json) {
    return ButtonGroup(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      buttons:
          (json['buttons'] as List)
              .map((buttonJson) => Button.fromJson(buttonJson))
              .toList(),
    );
  }

  /// Creates a copy of this group with optional property modifications
  ButtonGroup copyWith({
    String? id,
    String? name,
    String? color,
    List<Button>? buttons,
  }) {
    return ButtonGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      buttons: buttons ?? this.buttons,
    );
  }
}
