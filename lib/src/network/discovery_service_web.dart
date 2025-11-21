import 'dart:async';
import 'package:flutter/foundation.dart';

import 'discovery_service.dart';

/// Web implementation of discovery service (no-op for web platform)
class WebDiscoveryService implements DiscoveryService {
  final _discoveredServersController =
      StreamController<DiscoveredServer>.broadcast();

  @override
  Stream<DiscoveredServer> get discoveredServers =>
      _discoveredServersController.stream;

  @override
  Future<void> startBroadcasting({
    required String serverName,
    required int port,
  }) async {
    debugPrint('UDP discovery not supported on web platform');
  }

  @override
  Future<void> stopBroadcasting() async {
    // No-op
  }

  @override
  Future<void> startDiscovery() async {
    debugPrint('UDP discovery not supported on web platform');
  }

  @override
  Future<void> stopDiscovery() async {
    // No-op
  }

  @override
  Future<void> dispose() async {
    await _discoveredServersController.close();
  }
}

/// Factory function to create the discovery service
DiscoveryService createDiscoveryService() => WebDiscoveryService();
