import 'package:flutter/material.dart';

import '../models/button.dart';
import 'button_editor_dialog.dart';
import 'server.dart';

/// The main screen for the server application
class ServerScreen extends StatefulWidget {
  /// The server instance
  final MarcoServer server;

  /// Creates a server screen
  const ServerScreen({super.key, required this.server});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  String _serverIp = 'Loading...';
  int _serverPort = 8080;
  bool _isRunning = false;
  List<Button> _buttons = [];

  @override
  void initState() {
    super.initState();
    _initializeServer();
  }

  /// Initializes the server
  Future<void> _initializeServer() async {
    try {
      // Get the server IP address
      final ip = await widget.server.getServerIp();

      setState(() {
        _serverIp = ip;
        _serverPort = widget.server.serverPort;
      });

      // Start the server
      final success = await widget.server.start();

      setState(() {
        _isRunning = success;
      });

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start server'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Immediately load buttons after server start
        _refreshButtons();
      }
    } catch (e) {
      debugPrint('Error initializing server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Refreshes the list of buttons
  void _refreshButtons() {
    if (widget.server.isRunning) {
      setState(() {
        // Get the buttons from the server
        _buttons = widget.server.buttons;
      });
    }
  }

  /// Shows a dialog to add or edit a button
  Future<void> _showButtonDialog(Button? button) async {
    final result = await showDialog<Button>(
      context: context,
      builder: (context) => ButtonEditorDialog(button: button),
    );

    if (result != null) {
      if (button == null) {
        // Add new button
        widget.server.addButton(result);
      } else {
        // Update existing button
        widget.server.updateButton(result);
      }

      _refreshButtons();
    }
  }

  /// Deletes a button
  void _deleteButton(String id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Button'),
            content: const Text('Are you sure you want to delete this button?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.server.deleteButton(id);
                  _refreshButtons();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Converts a hex string to a Color
  Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  /// Gets an icon from a string code point
  IconData _getIconData(String iconName) {
    try {
      // Try to parse the icon as a code point
      final codePoint = int.tryParse(iconName);
      if (codePoint != null) {
        // Use FontAwesomeSolid font family for FontAwesome icons
        return IconData(
          codePoint,
          fontFamily: 'FontAwesomeSolid',
          fontPackage: 'font_awesome_flutter',
        );
      }
      return Icons.smart_button;
    } catch (e) {
      return Icons.smart_button;
    }
  }

  /// Gets the subtitle text for a button based on its type
  String _getButtonSubtitle(Button button) {
    switch (button.type) {
      case ButtonType.command:
        return button.command;
      case ButtonType.commandPreset:
        return button.command;
      case ButtonType.keystroke:
        final modifiers =
            button.modifiers.isNotEmpty
                ? '${button.modifiers.map((m) => m.toUpperCase()).join('+')}+'
                : '';
        return 'Keystroke: $modifiers${button.key.toUpperCase()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MarcoDeck Server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshButtons,
            tooltip: 'Refresh buttons',
          ),
        ],
      ),
      body: Column(
        children: [
          // Server status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Server Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRunning ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_isRunning ? 'Running' : 'Stopped'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('IP Address: $_serverIp'),
                  Text('Port: $_serverPort'),
                  const SizedBox(height: 16),
                  Text(
                    'Connect your client to: ws://$_serverIp:$_serverPort',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep this application running while clients are connected.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),

          // Buttons list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configured Buttons',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showButtonDialog(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New'),
                ),
              ],
            ),
          ),

          // Buttons list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: _buttons.isEmpty ? 1 : _buttons.length,
                itemBuilder: (context, index) {
                  if (_buttons.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No buttons configured yet. Click "Add New" to create your first button.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final button = _buttons[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _hexToColor(button.color),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconData(button.iconName),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(button.name),
                      subtitle: Text(_getButtonSubtitle(button)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showButtonDialog(button),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteButton(button.id),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
