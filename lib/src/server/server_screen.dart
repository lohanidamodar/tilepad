import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/button.dart' as models;
import '../models/client_info.dart';
import '../design/design.dart';
import 'button_editor_page.dart';
import 'plugins_screen.dart';
import 'server.dart';
import 'system_info.dart';
import 'page_editor_dialog.dart';
import 'widgets/server_status_card.dart';
import 'widgets/connected_clients_card.dart';
import 'widgets/pages_and_buttons_section.dart';
import 'widgets/button_library.dart';

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

  /// Opens the add-button picker for the selected page, then places the chosen
  /// (or newly authored) library button as a tile.
  /// Builds the connected-clients card wired to disconnect/block actions.
  Widget _buildClientsCard() {
    return ConnectedClientsCard(
      connectedClients: _connectedClients,
      blockedIps: widget.server.blockedIps,
      onDisconnect: (client) {
        widget.server.disconnectClient(client.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disconnected ${client.deviceName ?? client.ipAddress}',
            ),
          ),
        );
      },
      onBlock: (client) async {
        await widget.server.blockIp(client.ipAddress);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Blocked ${client.ipAddress}')),
        );
      },
      onUnblock: (ip) async {
        await widget.server.unblockIp(ip);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _addTile() async {
    final page = _selectedPage;
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a page first'),
          backgroundColor: context.tokens.color.danger,
        ),
      );
      return;
    }

    final result = await showButtonPicker(context, server: widget.server);
    if (result == null || !mounted) return;

    if (result.createNew) {
      await _createButtonAndPlace(page.id);
    } else if (result.preset != null) {
      final preset = result.preset!;
      final binding = preset.stateBinding;
      final isMonitor = binding?.stateId == systemSummaryStateId;

      // Live-state presets (system metrics) are singletons: reuse the existing
      // library button that represents the same state instead of cloning a new
      // one each time. Plain catalog presets (no binding) are always added
      // fresh so the user can place and customise several independently.
      models.Button? button;
      if (binding != null) {
        for (final b in widget.server.libraryButtons) {
          if (b.stateBinding?.pluginId == binding.pluginId &&
              b.stateBinding?.stateId == binding.stateId) {
            button = b;
            break;
          }
        }
      }
      if (button == null) {
        widget.server.addLibraryButton(preset);
        button = preset;
      }
      widget.server.addTile(
        page.id,
        button.id,
        colSpan: isMonitor ? 2 : 1,
        rowSpan: isMonitor ? 2 : 1,
      );
      _refreshPages();
    } else if (result.existing != null) {
      widget.server.addTile(page.id, result.existing!.id);
      _refreshPages();
    }
  }

  /// Authors a brand new library button via [ButtonEditorPage], adds it to the
  /// library, and places it on [pageId].
  Future<void> _createButtonAndPlace(String pageId) async {
    models.Button? created;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ButtonEditorPage(
          server: widget.server,
          onSave: (button) {
            created = button;
            widget.server.addLibraryButton(button);
            widget.server.addTile(pageId, button.id);
          },
        ),
      ),
    );
    if (created != null) _refreshPages();
  }

  /// Edits the library button behind a tile (changes apply everywhere it is
  /// placed).
  Future<void> _editTileButton(models.Tile tile) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ButtonEditorPage(
          button: tile.button,
          server: widget.server,
          onSave: (updated) {
            widget.server.updateButton(updated);
          },
        ),
      ),
    );
    _refreshPages();
  }

  /// Removes a tile (placement) from the selected page.
  void _removeTile(models.Tile tile) {
    final page = _selectedPage;
    if (page == null) return;
    widget.server.removeTile(page.id, tile.id);
    _refreshPages();
  }

  /// Resizes a tile on the selected page.
  void _resizeTile(models.Tile tile, int colSpan, int rowSpan) {
    final page = _selectedPage;
    if (page == null) return;
    widget.server.resizeTile(page.id, tile.id, colSpan, rowSpan);
    _refreshPages();
  }

  /// Reorders a tile within the selected page.
  void _reorderTile(int oldIndex, int newIndex) {
    final page = _selectedPage;
    if (page == null) return;
    widget.server.reorderTiles(page.id, oldIndex, newIndex);
    _refreshPages();
  }

  /// Updates the selected page's grid column count.
  void _setColumns(int columns) {
    final page = _selectedPage;
    if (page == null) return;
    page.columns = columns;
    widget.server.updatePage(page);
    _refreshPages();
  }

  /// Opens the library manager (edit/delete reusable buttons).
  Future<void> _openButtonLibrary() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => ButtonLibraryScreen(server: widget.server),
      ),
    );
    _refreshPages();
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
                Text(
                  'This is the name clients see when discovering this server.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: context.tokens.space.lg),
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
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                _serverName,
                style: textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: t.space.xxs),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: t.icon.sm),
              tooltip: 'Rename server',
              onPressed: _showRenameDialog,
              visualDensity: VisualDensity.compact,
              color: t.color.textMuted,
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
              backgroundColor: t.color.surfaceSubtle,
            ),
          ),
          SizedBox(width: t.space.sm),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On wide desktop windows, use a two-pane master/detail layout so the
          // horizontal space is put to good use. On narrow windows fall back to
          // a single scrolling column.
          final isWide = constraints.maxWidth >= 900;
          if (!isWide) {
            return ListView(
              padding: EdgeInsets.all(t.space.lg),
              children: [
                ServerStatusCard(
                  serverIp: _serverIp,
                  serverPort: _serverPort,
                  isRunning: _isRunning,
                  onRestartServer: _restartServer,
                  onToggleServer: _toggleServer,
                  onChangePort: _showChangePortDialog,
                ),
                if (_isRunning) _buildClientsCard(),
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
                  padding: EdgeInsets.fromLTRB(
                    t.space.lg,
                    t.space.lg,
                    t.space.sm,
                    t.space.lg,
                  ),
                  children: [
                    ServerStatusCard(
                      serverIp: _serverIp,
                      serverPort: _serverPort,
                      isRunning: _isRunning,
                      onRestartServer: _restartServer,
                      onToggleServer: _toggleServer,
                      onChangePort: _showChangePortDialog,
                    ),
                    if (_isRunning) _buildClientsCard(),
                  ],
                ),
              ),
              VerticalDivider(width: t.border.hairline),
              // Right pane: pages and buttons.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    t.space.sm,
                    t.space.lg,
                    t.space.lg,
                    t.space.lg,
                  ),
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
      onColumnsChanged: _setColumns,
      onAddTile: _addTile,
      onEditTile: _editTileButton,
      onRemoveTile: _removeTile,
      onResizeTile: _resizeTile,
      onReorderTile: _reorderTile,
      onManageButtons: _openButtonLibrary,
      onRunTile: (tile) => _runButtonOnServer(tile.button),
    );
  }

  /// Runs a tile/library button's actions on the server (test without a client)
  /// and reports the outcome.
  Future<void> _runButtonOnServer(models.Button button) async {
    final t = context.tokens;
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.server.executeButtonLocally(button);
    if (!mounted) return;
    final detail = result.output.isNotEmpty
        ? result.output
        : (result.error.isNotEmpty ? result.error : null);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: result.success ? t.color.success : t.color.danger,
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: t.color.onAccent,
                size: t.icon.md,
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Text(
                  detail == null
                      ? (result.success ? 'Ran "${button.name}"' : 'Failed')
                      : '${button.name}: $detail',
                  style: TextStyle(color: t.color.onAccent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }
}
