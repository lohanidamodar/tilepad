import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server_connection.dart';
import '../network/discovery_service.dart';
import '../utils/theme.dart';
import 'client_providers.dart';

/// Screen for connecting to a server
class ConnectionScreen extends ConsumerStatefulWidget {
  /// Existing connection to edit, if any
  final ServerConnection? existingConnection;

  /// Creates a connection screen
  const ConnectionScreen({super.key, this.existingConnection});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isConnecting = false;
  bool _isDiscovering = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // If editing an existing connection, load its values and show manual tab
    if (widget.existingConnection != null) {
      _nameController.text = widget.existingConnection!.name;
      _addressController.text = widget.existingConnection!.address;
      _tabController.index = 1; // Manual tab
    } else {
      // Default name
      _nameController.text = 'My Server';
      // Start discovery automatically
      _startDiscovery();
    }
  }

  @override
  void dispose() {
    _stopDiscovery();
    _nameController.dispose();
    _addressController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;
    setState(() => _isDiscovering = true);
    await ref.read(discoveredServersProvider.notifier).startDiscovery();
  }

  Future<void> _stopDiscovery() async {
    if (!_isDiscovering) return;
    await ref.read(discoveredServersProvider.notifier).stopDiscovery();
    setState(() => _isDiscovering = false);
  }

  /// Saves the server and optionally connects to it
  void _saveServer({bool connectAfterSave = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text;
    final address = _addressController.text;

    // Ensure address starts with ws:// or wss://
    final formattedAddress =
        address.startsWith('ws://') || address.startsWith('wss://')
            ? address
            : 'ws://$address';

    // Create or update the server connection
    final connection =
        widget.existingConnection != null
            ? widget.existingConnection!.copyWith(
              name: name,
              address: formattedAddress,
            )
            : ServerConnection(name: name, address: formattedAddress);

    // Save the connection
    ref.read(serverConnectionsProvider.notifier).addConnection(connection);

    if (connectAfterSave) {
      await _connectToServer(connection);
    } else {
      Navigator.pop(context);
    }
  }

  /// Attempts to connect to the server
  Future<void> _connectToServer(ServerConnection connection) async {
    setState(() {
      _isConnecting = true;
    });

    final success = await ref
        .read(connectionStateProvider.notifier)
        .connect(connection);

    setState(() {
      _isConnecting = false;
    });

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingConnection != null;
    final colorScheme = Theme.of(context).colorScheme;
    final discoveredServers = ref.watch(discoveredServersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'Add Server'),
        centerTitle: true,
        bottom:
            isEditing
                ? null
                : TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.search), text: 'Discover'),
                    Tab(icon: Icon(Icons.edit), text: 'Manual'),
                  ],
                ),
      ),
      body:
          isEditing
              ? _buildManualForm(context)
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoveryTab(context, colorScheme, discoveredServers),
                  _buildManualForm(context),
                ],
              ),
    );
  }

  Widget _buildDiscoveryTab(
    BuildContext context,
    ColorScheme colorScheme,
    List<DiscoveredServer> discoveredServers,
  ) {
    return Column(
      children: [
        if (_isDiscovering)
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            color: colorScheme.primaryContainer,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMedium),
                Expanded(
                  child: Text(
                    'Searching for servers on your network...',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child:
              discoveredServers.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_find,
                          size: 80,
                          color: colorScheme.onSurfaceVariant.withAlpha(127),
                        ),
                        const SizedBox(height: AppTheme.spaceXLarge),
                        Text(
                          _isDiscovering
                              ? 'Looking for servers...'
                              : 'No servers found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSmall),
                        Text(
                          'Make sure the server is running\non the same network',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppTheme.spaceXLarge),
                        FilledButton.tonalIcon(
                          onPressed: _isDiscovering ? null : _startDiscovery,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spaceLarge),
                    itemCount: discoveredServers.length,
                    itemBuilder: (context, index) {
                      final server = discoveredServers[index];
                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: AppTheme.spaceMedium,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(
                            AppTheme.spaceLarge,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(AppTheme.spaceMedium),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMedium,
                              ),
                            ),
                            child: Icon(
                              Icons.computer,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            server.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${server.ipAddress}:${server.port}'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => _addDiscoveredServer(server),
                                child: const Text('Add'),
                              ),
                              const SizedBox(width: AppTheme.spaceSmall),
                              FilledButton(
                                onPressed:
                                    () =>
                                        _addAndConnectDiscoveredServer(server),
                                child: const Text('Connect'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildManualForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Server Name',
                hintText: 'My Server',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a server name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Server Address',
                hintText: '192.168.1.100:8080',
                prefixIcon: const Icon(Icons.computer),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a server address';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _addressController.text = 'ws://localhost:8080';
                  },
                  child: const Text('Use localhost'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXLarge),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isConnecting ? null : () => _saveServer(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceLarge,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceLarge),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _isConnecting
                            ? null
                            : () => _saveServer(connectAfterSave: true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceLarge,
                      ),
                    ),
                    child:
                        _isConnecting
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Save & Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addDiscoveredServer(DiscoveredServer server) {
    final connection = ServerConnection(name: server.name, address: server.url);

    ref.read(serverConnectionsProvider.notifier).addConnection(connection);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${server.name}" to your servers'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _addAndConnectDiscoveredServer(DiscoveredServer server) async {
    final connection = ServerConnection(name: server.name, address: server.url);

    ref.read(serverConnectionsProvider.notifier).addConnection(connection);

    await _connectToServer(connection);
  }
}
