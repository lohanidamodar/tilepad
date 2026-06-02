import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/button.dart' as models;
import '../models/client_info.dart';
import '../design/design.dart';
import 'button_editor_page.dart';
import 'plugins_screen.dart';
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
  String _serverName = 'MarcoDeck Server';
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
      if (!mounted) return;
      setState(() {
        _connectedClients = clients;
      });
    });

    // Subscribe to server status updates
    _serverStatusSubscription = widget.server.serverStatusStream.listen((
      status,
    ) {
      // Showing a snackbar does not change widget state, so don't wrap it in
      // setState; just guard against the widget being disposed.
      if (mounted) {
        _showStatusMessage(status);
      }
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
    Color backgroundColor;
    final colorScheme = Theme.of(context).colorScheme;

    switch (status.type) {
      case ServerStatusType.started:
        backgroundColor = colorScheme.primaryContainer;
        break;
      case ServerStatusType.stopped:
        backgroundColor = colorScheme.errorContainer;
        break;
      case ServerStatusType.restarting:
        backgroundColor = colorScheme.secondaryContainer;
        break;
      case ServerStatusType.error:
        backgroundColor = colorScheme.error;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.message,
          style: TextStyle(
            color:
                backgroundColor.computeLuminance() > 0.5
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onErrorContainer,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(context.tokens.space.sm),
        shape: RoundedRectangleBorder(
          borderRadius: context.tokens.radius.brSm,
        ),
      ),
    );
  }

  /// Initializes the server
  Future<void> _initializeServer() async {
    try {
      final ip = await widget.server.getServerIp();

      if (!mounted) return;
      setState(() {
        _serverIp = ip;
        _serverPort = widget.server.serverPort;
        _portController.text = _serverPort.toString();
      });

      final success = await widget.server.start();

      if (!mounted) return;
      setState(() {
        _isRunning = success;
        _serverName = widget.server.name;
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
    if (!mounted) return;
    setState(() {
      _isRunning = success;
    });
    _refreshPages();
  }

  /// Toggles the server on/off
  Future<void> _toggleServer() async {
    if (_isRunning) {
      await widget.server.stop();
      if (!mounted) return;
      setState(() {
        _isRunning = false;
      });
    } else {
      final success = await widget.server.start();
      if (!mounted) return;
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
                      final success = await widget.server.restart(
                        newPort: newPort,
                      );
                      if (!mounted) return;
                      setState(() {
                        _isRunning = success;
                        _serverPort = newPort;
                      });
                    } else {
                      await widget.server.setPort(newPort);
                      if (!mounted) return;
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
  Future<void> _navigateToButtonEditor(models.Button? button) async {
    if (_selectedPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a page first'),
          backgroundColor: Colors.red,
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Reorders buttons within the selected page.
  ///
  /// Wired to [ReorderableListView]'s `onReorderItem`, which already adjusts
  /// `newIndex` for the removed item, so no manual adjustment is needed.
  void _reorderButtons(int oldIndex, int newIndex) {
    setState(() {
      if (_selectedPage == null) return;

      final button = _selectedPage!.buttons.removeAt(oldIndex);
      _selectedPage!.buttons.insert(newIndex, button);

      widget.server.updatePage(_selectedPage!);
    });
  }

  /// Shows a dialog to rename the server (the friendly name clients discover).
  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _serverName);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Server'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is the name clients see when discovering this server.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Server name'),
                  onSubmitted: (v) => Navigator.of(context).pop(v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await widget.server.setName(newName);
      if (!mounted) return;
      setState(() => _serverName = widget.server.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Renamed to "${widget.server.name}". '
              'Restart the server to broadcast the new name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Opens the shared appearance picker (theme mode, accent, density).
  void _showAppearanceSheet(BuildContext context) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.xl,
            t.space.sm,
            t.space.xl,
            t.space.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance',
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.space.lg),
              const PersonalizationPanel(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.desktop_windows_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _serverName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'MarcoDeck Server',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Rename server',
              onPressed: _showRenameDialog,
              visualDensity: VisualDensity.compact,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Appearance',
            onPressed: () => _showAppearanceSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.extension_outlined),
            tooltip: 'Plugins',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PluginsScreen(server: widget.server),
                ),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPages,
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On wide desktop windows, use a two-pane master/detail layout so the
          // horizontal space is put to good use. On narrow windows fall back to
          // a single scrolling column.
          final isWide = constraints.maxWidth >= 900;
          if (!isWide) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ServerStatusCard(
                  serverIp: _serverIp,
                  serverPort: _serverPort,
                  isRunning: _isRunning,
                  onRestartServer: _restartServer,
                  onToggleServer: _toggleServer,
                  onChangePort: _showChangePortDialog,
                ),
                if (_isRunning)
                  ConnectedClientsCard(connectedClients: _connectedClients),
                _buildPagesSection(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left pane: server status + connected clients.
              SizedBox(
                width: 360,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  children: [
                    ServerStatusCard(
                      serverIp: _serverIp,
                      serverPort: _serverPort,
                      isRunning: _isRunning,
                      onRestartServer: _restartServer,
                      onToggleServer: _toggleServer,
                      onChangePort: _showChangePortDialog,
                    ),
                    if (_isRunning)
                      ConnectedClientsCard(
                        connectedClients: _connectedClients,
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Right pane: pages and buttons.
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                  children: [_buildPagesSection()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPagesSection() {
    return PagesAndButtonsSection(
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
    );
  }
}
