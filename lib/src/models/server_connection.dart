import 'package:uuid/uuid.dart';

/// Model representing a saved server connection
class ServerConnection {
  /// Unique identifier for this connection
  final String id;

  /// Server name (user-friendly)
  final String name;

  /// Server address (including protocol)
  final String address;

  /// Last time this server was connected to
  final DateTime lastConnected;

  /// Creates a new server connection
  ServerConnection({
    String? id,
    required this.name,
    required this.address,
    DateTime? lastConnected,
  }) : id = id ?? const Uuid().v4(),
       lastConnected = lastConnected ?? DateTime.now();

  /// Creates a copy of this server connection with the specified fields replaced
  ServerConnection copyWith({
    String? name,
    String? address,
    DateTime? lastConnected,
  }) {
    return ServerConnection(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  /// Creates a server connection from JSON
  factory ServerConnection.fromJson(Map<String, dynamic> json) {
    return ServerConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
    );
  }

  /// Converts this server connection to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'lastConnected': lastConnected.toIso8601String(),
    };
  }
}
