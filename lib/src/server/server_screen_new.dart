import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/button.dart' as models;
import '../models/client_info.dart';
import '../design/design.dart';
import 'button_editor_page.dart';
import 'server.dart';
import 'page_editor_dialog.dart';
import 'widgets/server_status_card.dart';
import 'widgets/connected_clients_card.dart';
import 'widgets/pages_and_buttons_section.dart';

/// The main screen for the server application
class ServerScreen extends StatefulWidget {
  /// The server instance
  final MarcoServer server;

  /// Creates a server screen
  const ServerScreen({
    super.key,
    required this.server,
  });

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

  @override
  void dispose() {
    _clientsSubscription.cancel();
    _serverStatusSubscription.cancel();
    _portController.dispose();
    super.dispose();
  }

  /// Shows a status message based on the server status
  void _showStatusMessage(ServerStatus status) {
    final t = context.tokens;
    Color backgroundColor;
    Color foregroundColor;

    switch (status.type) {
      case ServerStatusType.started:
        backgroundColor = t.color.successSubtle;
        foregroundColor = t.color.success;
        break;
      case ServerStatusType.stopped:
        backgroundColor = t.color.dangerSubtle;
        foregroundColor = t.color.danger;
        break;
      case ServerStatusType.restarting:
        backgroundColor = t.color.warningSubtle;
        foregroundColor = t.color.warning;
        break;
      case ServerStatusType.error:
        backgroundColor = t.color.danger;
        foregroundColor = t.color.onAccent;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: foregroundColor),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(t.space.sm),
        shape: RoundedRectangleBorder(
          borderRadius: t.radius.brSm,
        ),
      ),
    );
  }

  /// Initializes the server
  Future<void> _initializeServer() async {
    try {
      final ip = await widget.server.getServerIp();

      setState(() {
        _serverIp = ip;
        _serverPort = widget.server.serverPort;
        _portController.text = _serverPort.toString();
      });

      final success = await widget.server.start();

      setState(() {
        _isRunning = success;
        _connectedClients = widget.server.connectedClients;
      });

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to start server'),
              backgroundColor: context.tokens.color.danger,
            ),
          );
        }
      } else {
        _refreshPages();
      }
    } catch (e) {
      debugPrint('Error initializing server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.color.danger,
          ),
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

  /// Toggles the server on/off
  Future<void> _toggleServer() async {
    if (_isRunning) {
      await widget.server.stop();
      setState(() {
        _isRunning = false;
      });
    } else {
      final success = await widget.server.start();
      setState(() {
        _isRunning = success;
      });
      if (success) {
        _refreshPages();
      }
    }
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
                Text(
                  'Enter a new port number between 1024 and 65535.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: context.tokens.space.lg),
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

                  if (newPort < 1024 || newPort > 65535) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Port must be between 1024 and 65535',
                          ),
                          backgroundColor: context.tokens.color.danger,
                        ),
                      );
                    }
                    return;
                  }

                  Navigator.of(context).pop();

                  if (newPort != _serverPort) {
                    if (_isRunning) {
                      final success = await widget.server.restart(
                        newPort: newPort,
                      );
                      setState(() {
                        _isRunning = success;
                        _serverPort = newPort;
                      });
                    } else {
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
        _pages = widget.server.pages;

        if (_selectedPage == null ||
            !_pages.any((p) => p.id == _selectedPage!.id)) {
          _selectedPage = _pages.isNotEmpty ? _pages.first : null;
        } else {
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
        widget.server.addPage(result);
      } else {
        widget.server.updatePage(result);
      }
      _refreshPages();
    }
  }

  /// Deletes a page
  void _deletePage(String id) {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Cannot delete the last page. Create a new page first.',
          ),
          backgroundColor: context.tokens.color.danger,
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

                  if (_selectedPage?.id == id) {
                    _selectedPage = null;
                  }

                  _refreshPages();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.color.danger,
                  foregroundColor: context.tokens.color.onAccent,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Navigate to the button editor page to add or edit a button
  Future<void> _navigateToButtonEditor(models.Button? button) async {
    if (_selectedPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a page first'),
          backgroundColor: context.tokens.color.danger,
        ),
      );
      return;
    }

    final result = await Navigator.push<models.Button>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ButtonEditorPage(
              button: button,
              server: widget.server,
              onSave: (updatedButton) {
                if (button == null) {
                  widget.server.addButton(updatedButton, _selectedPage!.id);
                } else {
                  widget.server.updateButton(updatedButton);
                }
                _refreshPages();
              },
            ),
      ),
    );

    if (result != null) {
      if (button == null) {
        widget.server.addButton(result, _selectedPage!.id);
      } else {
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
                  backgroundColor: context.tokens.color.danger,
                  foregroundColor: context.tokens.color.onAccent,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Reorders buttons within the selected page
  void _reorderButtons(int oldIndex, int newIndex) {
    setState(() {
      if (_selectedPage == null) return;

      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final button = _selectedPage!.buttons.removeAt(oldIndex);
      _selectedPage!.buttons.insert(newIndex, button);

      widget.server.updatePage(_selectedPage!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(t.space.sm),
              decoration: BoxDecoration(
                color: t.color.accentSubtle,
                borderRadius: t.radius.brSm,
              ),
              child: Icon(
                Icons.computer,
                color: t.color.accent,
                size: t.icon.lg,
              ),
            ),
            SizedBox(width: t.space.md),
            const Text('MarcoDeck Server'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPages,
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: t.color.surfaceSubtle,
            ),
          ),
          SizedBox(width: t.space.sm),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(t.space.lg),
        children: [
          // Server Status Card
          ServerStatusCard(
            serverIp: _serverIp,
            serverPort: _serverPort,
            isRunning: _isRunning,
            onRestartServer: _restartServer,
            onToggleServer: _toggleServer,
            onChangePort: _showChangePortDialog,
          ),

          // Connected Clients Card
          if (_isRunning)
            ConnectedClientsCard(connectedClients: _connectedClients),

          // Pages and Buttons Section
          PagesAndButtonsSection(
            pages: _pages,
            selectedPage: _selectedPage,
            onPageSelected: (page) => setState(() => _selectedPage = page),
            onAddPage: () => _showPageEditor(null),
            onEditPage: _showPageEditor,
            onDeletePage: _deletePage,
            onAddButton: () => _navigateToButtonEditor(null),
            onEditButton: _navigateToButtonEditor,
            onDeleteButton: _deleteButton,
            onReorderButtons: _reorderButtons,
          ),
        ],
      ),
    );
  }
}
