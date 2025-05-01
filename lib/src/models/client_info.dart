import 'dart:io';

/// Contains information about a connected client
class ClientInfo {
  /// Unique identifier for the client
  final String id;

  /// IP address of the client
  final String ipAddress;

  /// Time when the client connected
  final DateTime connectedAt;

  /// Optional name of the client device (if provided)
  final String? deviceName;

  /// Creates a new client info instance
  ClientInfo({
    required this.id,
    required this.ipAddress,
    required this.connectedAt,
    this.deviceName,
  });

  /// Creates a new client info from a WebSocket
  factory ClientInfo.fromWebSocket(WebSocket socket, [HttpRequest? request]) {
    final id = socket.hashCode.toString();

    // Default IP address if we can't determine it
    String ipAddress = 'Unknown';

    try {
      // If HttpRequest is available, get the client IP from it
      if (request != null) {
        ipAddress = request.connectionInfo?.remoteAddress.address ?? 'Unknown';
      }
    } catch (e) {
      // Fallback if we can't get remote address
    }

    return ClientInfo(
      id: id,
      ipAddress: ipAddress,
      connectedAt: DateTime.now(),
    );
  }
}
