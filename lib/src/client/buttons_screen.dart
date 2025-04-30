import 'package:flutter/material.dart';
import 'client.dart';
import 'button_grid.dart';
import '../models/button.dart';

/// Screen for displaying and interacting with buttons
class ButtonsScreen extends StatefulWidget {
  /// Client instance
  final MarcoClient client;

  /// Creates a buttons screen
  const ButtonsScreen({super.key, required this.client});

  @override
  State<ButtonsScreen> createState() => _ButtonsScreenState();
}

class _ButtonsScreenState extends State<ButtonsScreen> {
  List<Button> _buttons = [];
  bool _isConnected = false;
  String? _lastResultOutput;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();

    _isConnected = widget.client.isConnected;
    _buttons = widget.client.buttons;

    // Listen for button updates
    widget.client.buttonsStream.listen((buttons) {
      setState(() {
        _buttons = buttons;
      });
    });

    // Listen for connection status updates
    widget.client.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });

      if (connected) {
        // Request buttons when connected
        widget.client.requestButtons();
      }
    });

    // Listen for command results
    widget.client.resultStream.listen((event) {
      setState(() {
        _lastResultOutput =
            event.success ? event.output : 'Error: ${event.error}';
        _showResult = true;
      });
    });

    if (_isConnected) {
      // Initial request for buttons
      widget.client.requestButtons();
    }
  }

  /// Disconnect from the server and go back to the connection screen
  void _disconnect() async {
    await widget.client.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarcoDeck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.client.requestButtons,
            tooltip: 'Refresh buttons',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Button grid
          ButtonGrid(
            buttons: _buttons,
            client: widget.client,
            onButtonPressed: (buttonId) {
              // Clear any previous results when a button is pressed
              setState(() {
                _showResult = false;
              });
            },
          ),

          // Connection status indicator
          if (!_isConnected)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Reconnecting...',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _disconnect,
                    child: const Text('Back to Connection Screen'),
                  ),
                ],
              ),
            ),

          // Command result display
          if (_showResult && _lastResultOutput != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Result',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _showResult = false;
                            });
                          },
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: Text(
                          _lastResultOutput!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
