import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'discovery_service.dart';

/// UDP-based discovery service implementation for IO platforms
class IODiscoveryService implements DiscoveryService {
  static const int _discoveryPort = 37021; // UDP port for discovery
  static const String _multicastAddress = '239.255.37.21'; // Multicast group
  static const Duration _broadcastInterval = Duration(seconds: 3);
  static const Duration _serverTimeout = Duration(seconds: 10);

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  final _discoveredServersController =
      StreamController<DiscoveredServer>.broadcast();
  final Map<String, DiscoveredServer> _discoveredServers = {};

  String? _serverName;
  int? _serverPort;

  @override
  Stream<DiscoveredServer> get discoveredServers =>
      _discoveredServersController.stream;

  @override
  Future<void> startBroadcasting({
    required String serverName,
    required int port,
  }) async {
    try {
      _serverName = serverName;
      _serverPort = port;

      // Bind to any address on a random port for broadcasting
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _broadcastSocket!.broadcastEnabled = true;
      _broadcastSocket!.multicastLoopback =
          true; // Enable for same-machine discovery

      debugPrint(
        'Server broadcasting on UDP port $_discoveryPort (multicast: $_multicastAddress)',
      );

      // Start periodic broadcasts
      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        _broadcast();
      });

      // Initial broadcast
      _broadcast();
    } catch (e) {
      debugPrint('Error starting UDP broadcasting: $e');
      rethrow;
    }
  }

  void _broadcast() {
    if (_broadcastSocket == null ||
        _serverName == null ||
        _serverPort == null) {
      return;
    }

    try {
      final message = jsonEncode({
        'type': 'marco_deck_server',
        'name': _serverName,
        'port': _serverPort,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final bytes = utf8.encode(message);

      // Broadcast to multicast address
      final multicastSent = _broadcastSocket!.send(
        bytes,
        InternetAddress(_multicastAddress),
        _discoveryPort,
      );

      // Broadcast to localhost for same-machine discovery
      final localhostSent = _broadcastSocket!.send(
        bytes,
        InternetAddress.loopbackIPv4,
        _discoveryPort,
      );

      // Also broadcast to subnet broadcast address
      final broadcastSent = _broadcastSocket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );

      if (multicastSent > 0 || broadcastSent > 0 || localhostSent > 0) {
        debugPrint(
          'Broadcasting server: $_serverName on port $_serverPort (multicast: $multicastSent, localhost: $localhostSent, broadcast: $broadcastSent)',
        );
      }
    } catch (e) {
      debugPrint('Error broadcasting: $e');
    }
  }

  @override
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
    _serverName = null;
    _serverPort = null;
    debugPrint('Server stopped broadcasting');
  }

  @override
  Future<void> startDiscovery() async {
    try {
      // Bind to the discovery port with address reuse enabled
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );

      // Join multicast group
      final multicastAddress = InternetAddress(_multicastAddress);
      _listenSocket!.joinMulticast(multicastAddress);
      _listenSocket!.multicastLoopback =
          true; // Enable for same-machine discovery

      debugPrint(
        'Client listening for server broadcasts on port $_discoveryPort',
      );

      // Listen for incoming datagrams
      _listenSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket!.receive();
          if (datagram != null) {
            _handleDiscoveryMessage(datagram);
          }
        }
      });

      // Start cleanup timer to remove stale servers
      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _removeStaleServers();
      });
    } catch (e) {
      debugPrint('Error starting UDP discovery: $e');
      rethrow;
    }
  }

  void _handleDiscoveryMessage(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      debugPrint(
        'Received discovery message from ${datagram.address.address}: $message',
      );

      final data = jsonDecode(message) as Map<String, dynamic>;

      if (data['type'] != 'marco_deck_server') {
        debugPrint('Ignoring non-marco_deck message');
        return;
      }

      final serverName = data['name'] as String?;
      final serverPort = data['port'] as int?;
      final ipAddress = datagram.address.address;

      if (serverName == null || serverPort == null) {
        debugPrint('Invalid server data: name=$serverName, port=$serverPort');
        return;
      }

      final key = '$ipAddress:$serverPort';
      final server = DiscoveredServer(
        name: serverName,
        ipAddress: ipAddress,
        port: serverPort,
        lastSeen: DateTime.now(),
      );

      // Check if this is a new server or an update
      final isNew = !_discoveredServers.containsKey(key);
      _discoveredServers[key] = server;

      if (isNew) {
        debugPrint(
          '✓ Discovered NEW server: $serverName at $ipAddress:$serverPort',
        );
        _discoveredServersController.add(server);
      } else {
        debugPrint(
          'Updated existing server: $serverName at $ipAddress:$serverPort',
        );
      }
    } catch (e) {
      debugPrint('Error parsing discovery message: $e');
    }
  }

  void _removeStaleServers() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _discoveredServers.forEach((key, server) {
      if (now.difference(server.lastSeen) > _serverTimeout) {
        toRemove.add(key);
        debugPrint('Server timed out: ${server.name}');
      }
    });

    for (final key in toRemove) {
      _discoveredServers.remove(key);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    if (_listenSocket != null) {
      try {
        _listenSocket!.leaveMulticast(InternetAddress(_multicastAddress));
      } catch (e) {
        debugPrint('Error leaving multicast group: $e');
      }
      _listenSocket!.close();
      _listenSocket = null;
    }

    _discoveredServers.clear();
    debugPrint('Client stopped discovery');
  }

  @override
  Future<void> dispose() async {
    await stopBroadcasting();
    await stopDiscovery();
    await _discoveredServersController.close();
  }

  /// Get list of currently discovered servers
  List<DiscoveredServer> get currentServers =>
      _discoveredServers.values.toList();
}

/// Factory function to create the discovery service
DiscoveryService createDiscoveryService() => IODiscoveryService();
