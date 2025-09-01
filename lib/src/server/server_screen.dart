import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:marco_deck/src/models/button.dart';

import '../models/button.dart' as models;
import '../models/client_info.dart';
import '../utils/theme.dart';
import 'button_editor_page.dart';
import 'server.dart';
import 'page_editor_dialog.dart';

/// The main screen for the server application
class ServerScreen extends StatefulWidget {
  /// The server instance
  final MarcoServer server;

  /// Current theme mode
  final ThemeMode themeMode;

  /// Callback for when theme mode is changed
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// Creates a server screen
  const ServerScreen({
    super.key,
    required this.server,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
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
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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

  /// Reorders buttons within the selected page
  void _reorderButtons(int oldIndex, int newIndex) {
    setState(() {
      if (_selectedPage == null) return;

      if (newIndex > oldIndex) {
        // When moving down, the destination index needs to be decremented
        // because the item is removed before being inserted
        newIndex -= 1;
      }

      final button = _selectedPage!.buttons.removeAt(oldIndex);
      _selectedPage!.buttons.insert(newIndex, button);

      // Update the page with reordered buttons
      widget.server.updatePage(_selectedPage!);
    });
  }

  /// Executes the actions of a button directly from the server interface
  Future<void> _executeButtonAction(models.Button button) async {
    try {
      // Show a loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Executing action...'),
            ],
          ),
          duration: Duration(
            seconds: 60,
          ), // Long duration, will be closed manually
        ),
      );

      // Execute the actions
      final result = await widget.server.executeButtonLocally(button);

      // Close the loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show the result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.success ? Icons.check_circle : Icons.error,
                    color:
                        result.success
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.success
                        ? 'Action executed successfully'
                        : 'Error executing action',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (result.output.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Output: ${result.output}',
                    style: TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (result.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Error: ${result.error}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          backgroundColor:
              result.success ? Colors.green.shade800 : Colors.red.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
                Icons.computer,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('MarcoDeck Server'),
          ],
        ),
        actions: [
          // Theme mode selector
          if (widget.onThemeModeChanged != null)
            ThemeModeSelector(
              currentThemeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged!,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshPages,
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enhanced Server status card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: _isRunning ? 4 : 2,
              shadowColor: _isRunning 
                  ? colorScheme.primary.withOpacity(0.2)
                  : colorScheme.shadow.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced server status header
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isRunning
                            ? [
                                colorScheme.primaryContainer,
                                colorScheme.primaryContainer.withOpacity(0.8),
                              ]
                            : [
                                colorScheme.errorContainer,
                                colorScheme.errorContainer.withOpacity(0.8),
                              ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.dns_rounded,
                              color: _isRunning
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onErrorContainer,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Server Status',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _isRunning
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRunning
                                    ? Colors.green
                                    : colorScheme.error,
                                boxShadow: _isRunning
                                    ? [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: _isRunning
                                  ? const Center(
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isRunning ? 'Running' : 'Stopped',
                              style: TextStyle(
                                color: _isRunning
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Enhanced server info content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection info with improved styling
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.surfaceVariant.withOpacity(0.3),
                                colorScheme.surfaceVariant.withOpacity(0.1),
                              ],
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // IP Address row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.router_rounded,
                                      size: 20,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'IP Address',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _serverIp,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Port row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.settings_ethernet_rounded,
                                      size: 20,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Port',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_serverPort',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: _showChangePortDialog,
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('Change'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Enhanced connection URL
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primaryContainer,
                                colorScheme.primaryContainer.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Client Connection URL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.onPrimaryContainer.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        'ws://$_serverIp:$_serverPort',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: 'ws://$_serverIp:$_serverPort',
                                          ),
                                        ).then((_) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text('URL copied to clipboard'),
                                                ],
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                              backgroundColor: Colors.green.shade600,
                                            ),
                                          );
                                        });
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      label: const Text('Copy'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Use this URL in your mobile app to connect',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Enhanced server control buttons
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isRunning ? _restartServer : null,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Restart Server'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.tertiaryContainer,
                                  foregroundColor: colorScheme.onTertiaryContainer,
                                  disabledBackgroundColor: colorScheme.surface.withOpacity(0.3),
                                  disabledForegroundColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isRunning
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
                                icon: Icon(
                                  _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                ),
                                label: Text(
                                  _isRunning ? 'Stop Server' : 'Start Server',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _isRunning
                                      ? colorScheme.errorContainer
                                      : colorScheme.primaryContainer,
                                  foregroundColor: _isRunning
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onPrimaryContainer,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Enhanced Connected clients card
          if (_isRunning)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.secondaryContainer,
                            colorScheme.secondaryContainer.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.devices_rounded,
                              color: colorScheme.onSecondaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Connected Clients',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _connectedClients.isNotEmpty
                                  ? Colors.green.withOpacity(0.2)
                                  : colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _connectedClients.isNotEmpty
                                    ? Colors.green
                                    : colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _connectedClients.isNotEmpty
                                        ? Colors.green
                                        : colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_connectedClients.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _connectedClients.isNotEmpty
                                        ? Colors.green.shade700
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Enhanced clients list
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildConnectedClientsList(),
                    ),
                  ],
                ),
              ),
            ),

          // Enhanced Pages and buttons section
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced pages section header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.tertiaryContainer,
                          colorScheme.tertiaryContainer.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.dashboard_rounded,
                                color: colorScheme.onTertiaryContainer,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Button Pages',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_pages.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _showPageEditor(null),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('New Page'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.tertiary.withOpacity(0.3),
                                foregroundColor: colorScheme.onTertiaryContainer,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            if (_selectedPage != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_rounded,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                onPressed: () => _showPageEditor(_selectedPage),
                                tooltip: 'Edit Page',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.tertiary.withOpacity(0.2),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_rounded,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                onPressed: () => _deletePage(_selectedPage!.id),
                                tooltip: 'Delete Page',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.tertiary.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                // Page tabs
                if (_pages.isNotEmpty)
                  Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        final isSelected = _selectedPage?.id == page.id;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color:
                                isSelected
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surface.withAlpha(127),
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
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
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outline.withAlpha(70),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.grid_view,
                                      size: 16,
                                      color:
                                          isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      page.name,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurfaceVariant,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? colorScheme.primary
                                                : colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${page.buttons.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isSelected
                                                  ? colorScheme.onPrimary
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Buttons header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    color: colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedPage != null
                                ? '${_selectedPage!.name} Buttons'
                                : 'Buttons',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
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
                _selectedPage == null || _selectedPage!.buttons.isEmpty
                    ? Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: colorScheme.surface.withAlpha(127),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedPage == null
                                  ? Icons.dashboard_customize
                                  : Icons.touch_app,
                              size: 48,
                              color: colorScheme.primary.withAlpha(200),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedPage == null
                                  ? 'No page selected'
                                  : 'No buttons on this page yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedPage == null
                                  ? 'Please create or select a page first'
                                  : 'Click "Add Button" to create your first button',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed:
                                  _selectedPage == null
                                      ? () => _showPageEditor(null)
                                      : () => _navigateToButtonEditor(null),
                              icon: Icon(
                                _selectedPage == null
                                    ? Icons.add_circle
                                    : Icons.add,
                              ),
                              label: Text(
                                _selectedPage == null
                                    ? 'Create Page'
                                    : 'Add Button',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : ReorderableListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      onReorder: _reorderButtons,
                      itemCount: _selectedPage!.buttons.length,
                      itemBuilder: (context, index) {
                        final button = _selectedPage!.buttons[index];
                        return Card(
                          key: ValueKey(button.id),
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _navigateToButtonEditor(button),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 16,
                                  ),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.drag_handle,
                                        color: colorScheme.outlineVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _hexToColor(button.color),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(30),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _getIconData(button.iconName),
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    button.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Actions: ${button.actions.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      if (button.actions.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              _getActionTypeIcon(
                                                button.actions.first.type,
                                              ),
                                              size: 14,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _getActionDescription(
                                                  button.actions.first,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (button.actions.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            '+ ${button.actions.length - 1} more ${button.actions.length == 2 ? 'action' : 'actions'}',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: OverflowBar(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.play_arrow,
                                          color: colorScheme.primary,
                                        ),
                                        onPressed:
                                            () => _executeButtonAction(button),
                                        tooltip: 'Execute',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        onPressed:
                                            () =>
                                                _navigateToButtonEditor(button),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: colorScheme.error,
                                        ),
                                        onPressed:
                                            () => _deleteButton(button.id),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns an icon for the action type
  IconData _getActionTypeIcon(models.ActionType type) {
    switch (type) {
      case models.ActionType.command:
        return Icons.terminal;
      case models.ActionType.commandPreset:
        return Icons.playlist_play;
      case models.ActionType.keystroke:
        return Icons.keyboard;
    }
  }

  Widget _buildConnectedClientsList() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_connectedClients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smartphone_rounded,
                size: 32,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No clients connected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Clients will appear here when they connect to the server',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('h:mm:ss a');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _connectedClients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = _connectedClients[index];
        final connectionDuration = DateTime.now().difference(client.connectedAt);
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surfaceVariant.withOpacity(0.3),
                colorScheme.surface.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Enhanced device icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.smartphone_rounded,
                    size: 24,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Enhanced client info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device name
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.deviceName ?? 'Unknown Device',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Connection details
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          // IP Address
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_rounded,
                                size: 14,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                client.ipAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          
                          // Connection time
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(client.connectedAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          
                          // Connection duration
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 14,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(connectionDuration),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format duration in a human-readable way
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
