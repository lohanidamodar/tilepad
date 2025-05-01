import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:marco_deck/src/models/button.dart';

import '../models/button.dart' as models;
import '../models/client_info.dart';
import 'button_editor_page.dart';
import 'server.dart';
import 'page_editor_dialog.dart';

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
  List<models.Page> _pages = [];
  models.Page? _selectedPage;
  List<ClientInfo> _connectedClients = [];
  late StreamSubscription<List<ClientInfo>> _clientsSubscription;
  late StreamSubscription<ServerStatus> _serverStatusSubscription;

  // Text controller for the port input field
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serverPort = widget.server.serverPort;
    _portController.text = _serverPort.toString();
    _initializeServer();

    // Subscribe to client connection updates
    _clientsSubscription = widget.server.clientsStream.listen((clients) {
      setState(() {
        _connectedClients = clients;
      });
    });

    // Subscribe to server status updates
    _serverStatusSubscription = widget.server.serverStatusStream.listen((
      status,
    ) {
      setState(() {
        if (mounted) {
          _showStatusMessage(status);
        }
      });
    });
  }

  /// Shows a status message based on the server status
  void _showStatusMessage(ServerStatus status) {
    Color backgroundColor;

    switch (status.type) {
      case ServerStatusType.started:
        backgroundColor = Colors.green;
        break;
      case ServerStatusType.stopped:
        backgroundColor = Colors.orange;
        break;
      case ServerStatusType.restarting:
        backgroundColor = Colors.blue;
        break;
      case ServerStatusType.error:
        backgroundColor = Colors.red;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status.message), backgroundColor: backgroundColor),
    );
  }

  @override
  void dispose() {
    _clientsSubscription.cancel();
    _serverStatusSubscription.cancel();
    _portController.dispose();
    super.dispose();
  }

  /// Initializes the server
  Future<void> _initializeServer() async {
    try {
      // Get the server IP address
      final ip = await widget.server.getServerIp();

      setState(() {
        _serverIp = ip;
        _serverPort = widget.server.serverPort;
        _portController.text = _serverPort.toString();
      });

      // Start the server
      final success = await widget.server.start();

      setState(() {
        _isRunning = success;
        _connectedClients = widget.server.connectedClients;
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
        _refreshPages();
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

  /// Restarts the server with the current port
  Future<void> _restartServer() async {
    final success = await widget.server.restart();
    setState(() {
      _isRunning = success;
    });
    _refreshPages();
  }

  /// Shows a dialog to change the server port
  Future<void> _showChangePortDialog() async {
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Change Server Port'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter a new port number between 1024 and 65535.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newPort =
                      int.tryParse(_portController.text) ?? _serverPort;

                  // Validate port range
                  if (newPort < 1024 || newPort > 65535) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Port must be between 1024 and 65535'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  Navigator.of(context).pop();

                  if (newPort != _serverPort) {
                    if (_isRunning) {
                      // Restart server with the new port
                      final success = await widget.server.restart(
                        newPort: newPort,
                      );
                      setState(() {
                        _isRunning = success;
                        _serverPort = newPort;
                      });
                    } else {
                      // Just update the port if server is not running
                      await widget.server.setPort(newPort);
                      setState(() {
                        _serverPort = newPort;
                      });
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  /// Refreshes the list of pages and buttons
  void _refreshPages() {
    if (widget.server.isRunning) {
      setState(() {
        // Get the pages from the server
        _pages = widget.server.pages;

        // Select the first page if no page is selected or if the selected page no longer exists
        if (_selectedPage == null ||
            !_pages.any((p) => p.id == _selectedPage!.id)) {
          _selectedPage = _pages.isNotEmpty ? _pages.first : null;
        } else {
          // Update the selected page with the latest data
          _selectedPage = _pages.firstWhere((p) => p.id == _selectedPage!.id);
        }
      });
    }
  }

  /// Shows a dialog to add or edit a page
  Future<void> _showPageEditor(models.Page? page) async {
    final result = await showDialog<models.Page>(
      context: context,
      builder: (context) => PageEditorDialog(page: page),
    );

    if (result != null) {
      if (page == null) {
        // Add new page
        widget.server.addPage(result);
      } else {
        // Update existing page
        widget.server.updatePage(result);
      }
      _refreshPages();
    }
  }

  /// Deletes a page
  void _deletePage(String id) {
    // Don't allow deleting the last page
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot delete the last page. Create a new page first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Page'),
            content: const Text(
              'Are you sure you want to delete this page? All buttons on this page will be deleted as well.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.server.deletePage(id);

                  // If we're deleting the currently selected page, select another one
                  if (_selectedPage?.id == id) {
                    _selectedPage = null;
                  }

                  _refreshPages();
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

  /// Navigate to the button editor page to add or edit a button
  Future<void> _navigateToButtonEditor(Button? button) async {
    if (_selectedPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a page first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<Button>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ButtonEditorPage(
              button: button,
              onSave: (updatedButton) {
                if (button == null) {
                  // Add new button to the selected page
                  widget.server.addButton(updatedButton, _selectedPage!.id);
                } else {
                  // Update existing button
                  widget.server.updateButton(updatedButton);
                }
                _refreshPages();
              },
            ),
      ),
    );

    // If the page returns a result directly (though we use the onSave callback normally)
    if (result != null) {
      if (button == null) {
        // Add new button to the selected page
        widget.server.addButton(result, _selectedPage!.id);
      } else {
        // Update existing button
        widget.server.updateButton(result);
      }
      _refreshPages();
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
                  _refreshPages();
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

  /// Gets a description of a button action
  String _getActionDescription(ButtonAction action) {
    switch (action.type) {
      case ActionType.command:
        return 'Command: ${action.command}';
      case ActionType.commandPreset:
        return 'Preset: ${action.command}';
      case ActionType.keystroke:
        final modifierText =
            action.modifiers.isNotEmpty
                ? '${action.modifiers.map((m) => m.toUpperCase()).join('+')}+'
                : '';
        return 'Keystroke: $modifierText${action.key.toUpperCase()}';
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
            onPressed: _refreshPages,
            tooltip: 'Refresh',
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
                  Row(
                    children: [
                      Text('Port: $_serverPort'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16),
                        onPressed: _showChangePortDialog,
                        tooltip: 'Change Port',
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isRunning ? _restartServer : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restart Server'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            _isRunning
                                ? () async {
                                  await widget.server.stop();
                                  setState(() {
                                    _isRunning = false;
                                  });
                                }
                                : () async {
                                  final success = await widget.server.start();
                                  setState(() {
                                    _isRunning = success;
                                  });
                                  if (success) {
                                    _refreshPages();
                                  }
                                },
                        icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(
                          _isRunning ? 'Stop Server' : 'Start Server',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isRunning ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Connected clients card
          if (_isRunning)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Clients (${_connectedClients.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildConnectedClientsList(),
                  ],
                ),
              ),
            ),

          // Pages tabs and management
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pages (${_pages.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showPageEditor(null),
                      icon: const Icon(Icons.add),
                      label: const Text('New Page'),
                    ),
                    if (_selectedPage != null)
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showPageEditor(_selectedPage),
                            tooltip: 'Edit Page',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deletePage(_selectedPage!.id),
                            tooltip: 'Delete Page',
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Page tabs
          if (_pages.isNotEmpty)
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final isSelected = _selectedPage?.id == page.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPage = page;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            page.name,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                      : Theme.of(
                                        context,
                                      ).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${page.buttons.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSelected
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Buttons list header
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedPage != null
                      ? '${_selectedPage!.name} Buttons'
                      : 'Buttons',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _selectedPage != null
                          ? () => _navigateToButtonEditor(null)
                          : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Button'),
                ),
              ],
            ),
          ),

          // Buttons list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child:
                  _selectedPage == null || _selectedPage!.buttons.isEmpty
                      ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _selectedPage == null
                                ? 'No page selected. Please create or select a page.'
                                : 'No buttons on this page yet. Click "Add Button" to create your first button.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _selectedPage!.buttons.length,
                        itemBuilder: (context, index) {
                          final button = _selectedPage!.buttons[index];
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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Actions: ${button.actions.length}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (button.actions.isNotEmpty)
                                    Text(
                                      _getActionDescription(
                                        button.actions.first,
                                      ),
                                    ),
                                  if (button.actions.length > 1)
                                    Text(
                                      '+ ${button.actions.length - 1} more ${button.actions.length == 2 ? 'action' : 'actions'}',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed:
                                        () => _navigateToButtonEditor(button),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteButton(button.id),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                              onTap: () => _navigateToButtonEditor(button),
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

  Widget _buildConnectedClientsList() {
    if (_connectedClients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No clients connected'),
      );
    }

    final dateFormat = DateFormat('h:mm:ss a');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _connectedClients.length,
      itemBuilder: (context, index) {
        final client = _connectedClients[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.smartphone, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.deviceName ?? 'Unknown Device',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'IP: ${client.ipAddress} • Connected at: ${dateFormat.format(client.connectedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
