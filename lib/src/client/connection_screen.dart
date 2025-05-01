import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server_connection.dart';
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

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();

    // If editing an existing connection, load its values
    if (widget.existingConnection != null) {
      _nameController.text = widget.existingConnection!.name;
      _addressController.text = widget.existingConnection!.address;
    } else {
      // Default name
      _nameController.text = 'My Server';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'Add Server'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Server Name',
                  hintText: 'My Server',
                  prefixIcon: const Icon(Icons.label),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a server name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Server Address',
                  hintText: '192.168.1.100:8080',
                  prefixIcon: const Icon(Icons.computer),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isConnecting ? null : () => _saveServer(),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _isConnecting
                              ? null
                              : () => _saveServer(connectAfterSave: true),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }
}
