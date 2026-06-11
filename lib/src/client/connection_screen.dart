import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design.dart';
import '../models/server_connection.dart';
import '../network/discovery_service.dart';
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
  final _pinController = TextEditingController();
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
      _pinController.text = widget.existingConnection!.pin;
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
    _pinController.dispose();
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
    if (!mounted) return;
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
    final pin = _pinController.text.trim();
    final connection = widget.existingConnection != null
        ? widget.existingConnection!.copyWith(
            name: name,
            address: formattedAddress,
            pin: pin,
          )
        : ServerConnection(name: name, address: formattedAddress, pin: pin);

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
        SnackBar(
          content: const Text('Failed to connect to server'),
          backgroundColor: context.tokens.color.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingConnection != null;
    final discoveredServers = ref.watch(discoveredServersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'Add Server'),
        centerTitle: true,
        bottom: isEditing
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.search), text: 'Discover'),
                  Tab(icon: Icon(Icons.edit), text: 'Manual'),
                ],
              ),
      ),
      body: isEditing
          ? _buildManualForm(context)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDiscoveryTab(context, discoveredServers),
                _buildManualForm(context),
              ],
            ),
    );
  }

  Widget _buildDiscoveryTab(
    BuildContext context,
    List<DiscoveredServer> discoveredServers,
  ) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        if (_isDiscovering)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space.lg,
              vertical: tokens.space.md,
            ),
            decoration: BoxDecoration(
              color: tokens.color.surfaceSubtle,
              border: Border(
                bottom: BorderSide(
                  color: tokens.color.border,
                  width: tokens.border.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: tokens.icon.sm,
                  height: tokens.icon.sm,
                  child: CircularProgressIndicator(
                    strokeWidth: tokens.border.focus,
                    color: tokens.color.textMuted,
                  ),
                ),
                SizedBox(width: tokens.space.md),
                Expanded(
                  child: Text(
                    'Searching for servers on your network...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.color.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: discoveredServers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_find,
                        size: tokens.space.huge,
                        color: tokens.color.textMuted,
                      ),
                      SizedBox(height: tokens.space.xl),
                      Text(
                        _isDiscovering
                            ? 'Looking for servers...'
                            : 'No servers found',
                        style: textTheme.titleMedium?.copyWith(
                          color: tokens.color.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.space.sm),
                      Text(
                        'Make sure the server is running\non the same network',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.color.textSecondary,
                        ),
                      ),
                      SizedBox(height: tokens.space.xl),
                      FilledButton.tonalIcon(
                        onPressed: _isDiscovering ? null : _startDiscovery,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(tokens.space.lg),
                  itemCount: discoveredServers.length,
                  itemBuilder: (context, index) {
                    final server = discoveredServers[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: tokens.space.md),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(tokens.space.lg),
                        leading: Icon(
                          Icons.dns_outlined,
                          size: tokens.icon.xl,
                          color: tokens.color.textSecondary,
                        ),
                        title: Text(server.name, style: textTheme.titleMedium),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: tokens.space.xs),
                          child: Text(
                            '${server.ipAddress}:${server.port}',
                            style: AppTypography.mono(
                              fontSize: tokens.typeScale.bodySm,
                              color: tokens.color.textMuted,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => _addDiscoveredServer(server),
                              child: const Text('Add'),
                            ),
                            SizedBox(width: tokens.space.sm),
                            FilledButton(
                              onPressed: () =>
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
    final tokens = context.tokens;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space.lg),
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
                border: OutlineInputBorder(borderRadius: tokens.radius.brMd),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a server name';
                }
                return null;
              },
            ),
            SizedBox(height: tokens.space.lg),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Server Address',
                hintText: '192.168.1.100:8080',
                prefixIcon: const Icon(Icons.computer),
                border: OutlineInputBorder(borderRadius: tokens.radius.brMd),
              ),
              keyboardType: TextInputType.url,
              style: AppTypography.mono(color: tokens.color.textPrimary),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a server address';
                }
                return null;
              },
            ),
            SizedBox(height: tokens.space.sm),
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
            SizedBox(height: tokens.space.sm),
            TextFormField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: 'PIN (optional)',
                hintText: 'Only if the server requires pairing',
                prefixIcon: const Icon(Icons.pin_outlined),
                border: OutlineInputBorder(borderRadius: tokens.radius.brMd),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
            ),
            SizedBox(height: tokens.space.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isConnecting ? null : () => _saveServer(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: tokens.radius.brMd,
                      ),
                      padding: EdgeInsets.symmetric(vertical: tokens.space.lg),
                    ),
                    child: const Text('Save'),
                  ),
                ),
                SizedBox(width: tokens.space.lg),
                Expanded(
                  child: FilledButton(
                    onPressed: _isConnecting
                        ? null
                        : () => _saveServer(connectAfterSave: true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: tokens.radius.brMd,
                      ),
                      padding: EdgeInsets.symmetric(vertical: tokens.space.lg),
                    ),
                    child: _isConnecting
                        ? SizedBox(
                            height: tokens.icon.lg,
                            width: tokens.icon.lg,
                            child: CircularProgressIndicator(
                              strokeWidth: tokens.border.focus,
                              color: tokens.color.onAccent,
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
