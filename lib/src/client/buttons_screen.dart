import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marco_deck/src/network/websocket_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../models/server_connection.dart';
import 'client_providers.dart';
import 'button_grid.dart';
import 'server_list_screen.dart';
import 'connection_screen.dart';
import 'settings_screen.dart';

/// Screen for displaying and interacting with buttons
class ButtonsScreen extends ConsumerStatefulWidget {
  /// Creates a buttons screen
  ///
  /// If [showNoConnectionMessage] is true, a message will be shown prompting the user
  /// to connect to a server if no connection is active
  const ButtonsScreen({super.key, this.showNoConnectionMessage = false});

  /// Whether to show a message prompting the user to connect to a server
  final bool showNoConnectionMessage;

  @override
  ConsumerState<ButtonsScreen> createState() => _ButtonsScreenState();
}

class _ButtonsScreenState extends ConsumerState<ButtonsScreen> {
  bool _showResult = false;
  final PageController _pageController = PageController();

  // Reference to the WebSocket service
  late final ClientWebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();

    // Initialize WebSocket service reference
    _webSocketService = ClientWebSocketService();

    // Request buttons from server when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionState = ref.read(connectionStateProvider);
      if (connectionState.status == ConnectionStatus.connected) {
        // If already connected (e.g., from splash screen), request buttons
        debugPrint('ButtonsScreen: Already connected, requesting buttons');
        ref.read(connectionStateProvider.notifier).requestButtons();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showServerManager(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ServerListScreen()));
  }

  void _showAddServerDialog(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ConnectionScreen()));
  }

  void _connectToDefault(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    // Get the default server ID using the provider
    final connectionsNotifier = ref.read(serverConnectionsProvider.notifier);
    final defaultServerId = connectionsNotifier.defaultServerId;
    final serverConnections = ref.read(serverConnectionsProvider);

    // Find the default server by ID
    ServerConnection? defaultServer;
    if (defaultServerId != null) {
      try {
        defaultServer = serverConnections.firstWhere(
          (conn) => conn.id == defaultServerId,
        );
      } catch (_) {
        // No server found with this ID
        defaultServer = null;
      }
    }

    if (defaultServer != null) {
      // Try to connect to the default server
      final connectionNotifier = ref.read(connectionStateProvider.notifier);

      // First ensure we're disconnected
      await connectionNotifier.disconnect();

      // Now attempt to connect
      final success = await connectionNotifier.connect(defaultServer);
      if (success) {
        // Request buttons from server after successful connection
        connectionNotifier.requestButtons();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${defaultServer.name}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colorScheme.primaryContainer,
            showCloseIcon: true,
            closeIconColor: colorScheme.onPrimaryContainer,
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to connect to default server'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colorScheme.errorContainer,
            showCloseIcon: true,
            closeIconColor: colorScheme.onErrorContainer,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No default server set'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.surface,
          showCloseIcon: true,
        ),
      );
    }
  }

  void _showSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  /// Handles connection loss by attempting to reconnect
  void _handleConnectionLoss(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final connectionState = ref.read(connectionStateProvider);

    // Show dialog to inform the user
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                const Text('Connection Lost'),
              ],
            ),
            content: const Text(
              'The connection to the server has been lost. Would you like to reconnect?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();

                  // Attempt to reconnect if we have connection info
                  if (connectionState.connection != null) {
                    ref
                        .read(connectionStateProvider.notifier)
                        .connect(connectionState.connection!);
                  }
                },
                child: const Text('Reconnect'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final pages = ref.watch(pagesProvider);
    final selectedPageIndex = ref.watch(selectedPageIndexProvider);
    final commandResult = ref.watch(commandResultProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // More robust connection status check - only show buttons if truly connected
    final isConnected = connectionState.status == ConnectionStatus.connected;

    // For debugging - log connection state changes
    debugPrint('ButtonsScreen: Connection status: ${connectionState.status}');

    // Connection lost detection for more responsive UI
    if (connectionState.status == ConnectionStatus.disconnected &&
        pages.isNotEmpty) {
      // If we have buttons but the connection is gone, clear the buttons
      // This ensures we don't show stale buttons from a previous connection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pagesProvider.notifier).state = [];
      });
    }

    // Synchronize page controller with the selected index from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          _pageController.page?.round() != selectedPageIndex &&
          selectedPageIndex < pages.length) {
        _pageController.animateToPage(
          selectedPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              connectionState.connection?.name ?? 'MarcoDeck',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isConnected)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh buttons',
              style: IconButton.styleFrom(foregroundColor: colorScheme.primary),
              onPressed: () {
                // Before refreshing, ensure connection is active
                if (_webSocketService.isConnected) {
                  ref.read(connectionStateProvider.notifier).requestButtons();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Buttons refreshed'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                      backgroundColor: colorScheme.primaryContainer,
                      showCloseIcon: true,
                    ),
                  );
                } else {
                  // Connection lost, attempt to reconnect
                  _handleConnectionLoss(context);
                }
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              switch (value) {
                case 'servers':
                  _showServerManager(context);
                  break;
                case 'add_server':
                  _showAddServerDialog(context);
                  break;
                case 'connect_default':
                  _connectToDefault(context);
                  break;
                case 'disconnect':
                  ref.read(connectionStateProvider.notifier).disconnect();
                  break;
                case 'settings':
                  _showSettings(context);
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings, color: colorScheme.primary),
                      title: const Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'servers',
                    child: ListTile(
                      leading: Icon(Icons.computer, color: colorScheme.primary),
                      title: const Text('Manage Servers'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_server',
                    child: ListTile(
                      leading: Icon(
                        Icons.add_circle_outline,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Add New Server'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  if (!isConnected)
                    PopupMenuItem<String>(
                      value: 'connect_default',
                      child: ListTile(
                        leading: Icon(Icons.link, color: colorScheme.primary),
                        title: const Text('Connect to Default'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (isConnected)
                    PopupMenuItem<String>(
                      value: 'disconnect',
                      child: ListTile(
                        leading: Icon(Icons.link_off, color: colorScheme.error),
                        title: Text(
                          'Disconnect',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Button grid or no connection message
          if (isConnected)
            Column(
              children: [
                // Page name and indicator container
                if (pages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withAlpha(30),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Page name
                        if (pages.isNotEmpty &&
                            selectedPageIndex < pages.length)
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              pages[selectedPageIndex].name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Page indicator dots
                        if (pages.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: SmoothPageIndicator(
                              controller: _pageController,
                              count: pages.length,
                              effect: WormEffect(
                                dotHeight: 8,
                                dotWidth: 8,
                                activeDotColor: colorScheme.primary,
                                dotColor: colorScheme.surface,
                                spacing: 8,
                                radius: 4,
                              ),
                              onDotClicked: (index) {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                // Page view with button grids
                Expanded(
                  child:
                      pages.isEmpty
                          ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withAlpha(127),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 48,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No buttons configured',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Configure buttons in the server application',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                          : PageView.builder(
                            controller: _pageController,
                            itemCount: pages.length,
                            onPageChanged: (index) {
                              ref
                                  .read(selectedPageIndexProvider.notifier)
                                  .state = index;
                            },
                            itemBuilder: (context, index) {
                              final page = pages[index];
                              return ButtonGrid(
                                buttons: page.buttons,
                                onButtonPressed: (buttonId) {
                                  // Press the button via the connection state notifier
                                  ref
                                      .read(connectionStateProvider.notifier)
                                      .pressButton(buttonId);

                                  // Clear any previous results when a button is pressed
                                  setState(() {
                                    _showResult = false;
                                  });
                                },
                              );
                            },
                          ),
                ),
              ],
            )
          else
            _buildNoConnectionView(context),

          // Connection status indicator for connecting/error/reconnecting state
          if (connectionState.status == ConnectionStatus.connecting ||
              connectionState.status == ConnectionStatus.error ||
              connectionState.status == ConnectionStatus.reconnecting)
            Container(
              color: colorScheme.scrim.withAlpha(200),
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withAlpha(50),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (connectionState.status == ConnectionStatus.reconnecting)
                      // Pulsating reconnection animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: Icon(
                          Icons.sync,
                          color: colorScheme.primary,
                          size: 48,
                        ),
                      )
                    else
                      CircularProgressIndicator(
                        color:
                            connectionState.status ==
                                    ConnectionStatus.connecting
                                ? colorScheme.primary
                                : colorScheme.error,
                      ),
                    const SizedBox(height: 24),
                    Text(
                      connectionState.status == ConnectionStatus.connecting
                          ? 'Connecting...'
                          : connectionState.status ==
                              ConnectionStatus.reconnecting
                          ? 'Reconnecting...'
                          : 'Connection Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            connectionState.status == ConnectionStatus.error
                                ? colorScheme.error
                                : colorScheme.primary,
                      ),
                    ),
                    if (connectionState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          connectionState.errorMessage!,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (connectionState.status == ConnectionStatus.error)
                          FilledButton.icon(
                            onPressed: () {
                              ref
                                  .read(connectionStateProvider.notifier)
                                  .refreshConnection();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        if (connectionState.status ==
                            ConnectionStatus.reconnecting) ...[
                          FilledButton.icon(
                            onPressed: () {
                              // Cancel the automatic reconnection and manually reconnect
                              ref
                                  .read(connectionStateProvider.notifier)
                                  .cancelReconnection();
                              if (connectionState.connection != null) {
                                ref
                                    .read(connectionStateProvider.notifier)
                                    .connect(connectionState.connection!);
                              }
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('Reconnect Now'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              // Cancel the reconnection attempt
                              ref
                                  .read(connectionStateProvider.notifier)
                                  .cancelReconnection();
                            },
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () {
                              if (connectionState.status ==
                                  ConnectionStatus.connecting) {
                                // Cancel connection attempt
                                ref
                                    .read(connectionStateProvider.notifier)
                                    .cancelConnection();
                              } else {
                                // Dismiss error
                                ref
                                    .read(connectionStateProvider.notifier)
                                    .resetErrorState();
                              }
                            },
                            child: Text(
                              connectionState.status ==
                                      ConnectionStatus.connecting
                                  ? 'Cancel'
                                  : 'Dismiss',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Command result display
          if (_showResult && commandResult != null ||
              commandResult != null && !_showResult)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Card(
                margin: const EdgeInsets.all(12),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            commandResult.success
                                ? colorScheme.primaryContainer
                                : colorScheme.errorContainer,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withAlpha(30),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                commandResult.success
                                    ? Icons.check_circle
                                    : Icons.error,
                                color:
                                    commandResult.success
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                commandResult.success
                                    ? 'Command Result'
                                    : 'Command Error',
                                style: TextStyle(
                                  color:
                                      commandResult.success
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color:
                                  commandResult.success
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onErrorContainer,
                            ),
                            onPressed: () {
                              setState(() {
                                _showResult = false;
                              });
                            },
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              commandResult.success
                                  ? commandResult.output
                                  : 'Error: ${commandResult.error}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
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

  Widget _buildNoConnectionView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(127),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(305),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 24),
              child: Image.asset(
                'assets/logo.png',
                height: 100,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.devices,
                      size: 80,
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
            Text(
              'Not Connected',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to a server to view and use your macro buttons',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.computer),
              label: const Text('Choose Server'),
              onPressed: () => _showServerManager(context),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                minimumSize: const Size(240, 0),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Server'),
              onPressed: () => _showAddServerDialog(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                minimumSize: const Size(240, 0),
              ),
            ),
            if (ref.read(serverConnectionsProvider.notifier).defaultServerId !=
                null) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.link),
                label: const Text('Connect to Default Server'),
                onPressed: () => _connectToDefault(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
