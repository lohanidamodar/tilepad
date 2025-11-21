import 'dart:async';

/// Information about a discovered server
class DiscoveredServer {
  /// Server name
  final String name;

  /// Server IP address
  final String ipAddress;

  /// Server WebSocket port
  final int port;

  /// Time when server was last seen
  final DateTime lastSeen;

  DiscoveredServer({
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
  });

  /// WebSocket URL for connecting to this server
  String get url => 'ws://$ipAddress:$port';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredServer &&
          runtimeType == other.runtimeType &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;

  @override
  String toString() => 'DiscoveredServer($name at $ipAddress:$port)';
}

/// Abstract service for UDP-based server discovery
abstract class DiscoveryService {
  /// Stream of discovered servers
  Stream<DiscoveredServer> get discoveredServers;

  /// Start broadcasting server presence (server-side)
  Future<void> startBroadcasting({
    required String serverName,
    required int port,
  });

  /// Stop broadcasting server presence (server-side)
  Future<void> stopBroadcasting();

  /// Start listening for server broadcasts (client-side)
  Future<void> startDiscovery();

  /// Stop listening for server broadcasts (client-side)
  Future<void> stopDiscovery();

  /// Clean up resources
  Future<void> dispose();
}
