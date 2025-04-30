import 'package:flutter/material.dart';
import 'client.dart';

/// Screen for connecting to a server
class ConnectionScreen extends StatefulWidget {
  /// Client instance
  final MarcoClient client;

  /// Called when connection is successful
  final VoidCallback onConnected;

  /// Creates a connection screen
  const ConnectionScreen({
    super.key,
    required this.client,
    required this.onConnected,
  });

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();

    // Load saved server address if available
    _addressController.text = widget.client.serverAddress ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Attempts to connect to the server
  void _connect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    final address = _addressController.text;

    // Ensure address starts with ws:// or wss://
    final formattedAddress =
        address.startsWith('ws://') || address.startsWith('wss://')
            ? address
            : 'ws://$address';

    final success = await widget.client.connect(formattedAddress);

    setState(() {
      _isConnecting = false;
    });

    if (success) {
      widget.onConnected();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to server'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 120,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.devices,
                      size: 80,
                      color: Colors.blueGrey,
                    ),
              ),
              const SizedBox(height: 32),
              Text(
                'MarcoDeck',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to your MarcoDeck server',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isConnecting
                          ? const CircularProgressIndicator()
                          : const Text(
                            'Connect',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _addressController.text = 'ws://localhost:8080';
                },
                child: const Text('Use localhost (same device)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
