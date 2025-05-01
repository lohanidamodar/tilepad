import 'dart:convert';

/// Types of messages that can be exchanged between client and server
enum MessageType {
  /// Connection establishment message
  connect,

  /// Connection acknowledgment
  connectAck,

  /// Request for available buttons
  getButtons,

  /// Response with available buttons
  buttonsResponse,

  /// Response with available pages and their buttons
  pagesResponse,

  /// Button press event
  buttonPress,

  /// Command execution result
  commandResult,

  /// Button configuration update
  updateButton,

  /// Error message
  error,
}

/// A message that can be sent between the client and server
class Message {
  /// The type of the message
  final MessageType type;

  /// The payload of the message (can be any JSON-serializable data)
  final dynamic payload;

  /// Creates a new message with the given type and payload
  Message({required this.type, this.payload});

  /// Creates a message from a JSON map
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      type: MessageType.values.byName(json['type']),
      payload: json['payload'],
    );
  }

  /// Converts this message to a JSON map
  Map<String, dynamic> toJson() {
    return {'type': type.name, 'payload': payload};
  }

  /// Encodes this message to a JSON string
  String encode() {
    return jsonEncode(toJson());
  }

  /// Decodes a JSON string to a message
  static Message decode(String jsonStr) {
    final Map<String, dynamic> json = jsonDecode(jsonStr);
    return Message.fromJson(json);
  }
}
