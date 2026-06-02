import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../design/design.dart';
import '../models/server_connection.dart';
import '../utils/accessibility.dart';
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
  final PageController _pageController = PageController();

  /// True while we have just connected and are still waiting for the server to
  /// send its buttons, so we can show a loading skeleton instead of an abrupt
  /// "no buttons" state.
  bool _awaitingButtons = false;
  Timer? _awaitTimer;

  @override
  void initState() {
    super.initState();

    // Request buttons from server when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionState = ref.read(connectionStateProvider);
      if (connectionState.status == ConnectionStatus.connected) {
        // If already connected (e.g., from splash screen), request buttons
        debugPrint('ButtonsScreen: Already connected, requesting buttons');
        ref.read(connectionStateProvider.notifier).requestButtons();
        _beginAwaitingButtons();
      }
    });
  }

  @override
  void dispose() {
    _awaitTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Begins a short window during which a loading skeleton is shown while the
  /// server's buttons are in flight.
  void _beginAwaitingButtons() {
    _awaitTimer?.cancel();
    setState(() => _awaitingButtons = true);
    _awaitTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _awaitingButtons = false);
    });
  }

  void _showResultBottomSheet(BuildContext context, CommandResultEvent result) {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: tokens.color.surfaceRaised,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(tokens.radius.lg),
                    ),
                    boxShadow: tokens.shadowMd,
                  ),
                  child: Column(
                    children: [
                      // Header with drag handle
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.space.lg,
                          vertical: tokens.space.md,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: tokens.color.border,
                              width: tokens.border.hairline,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: tokens.space.huge - tokens.space.sm,
                                height: tokens.space.xs,
                                margin: EdgeInsets.only(
                                  bottom: tokens.space.md,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.color.border,
                                  borderRadius: tokens.radius.brXs,
                                ),
                              ),
                            ),
                            // Title row
                            Row(
                              children: [
                                Container(
                                  width: tokens.space.sm,
                                  height: tokens.space.sm,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: result.success
                                        ? tokens.color.success
                                        : tokens.color.danger,
                                  ),
                                ),
                                SizedBox(width: tokens.space.md),
                                Expanded(
                                  child: Text(
                                    result.success
                                        ? 'Command Result'
                                        : 'Command Error',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: tokens.color.textSecondary,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.all(tokens.space.lg),
                          children: [
                            Container(
                              padding: EdgeInsets.all(tokens.space.lg),
                              decoration: BoxDecoration(
                                color: tokens.color.surfaceSubtle,
                                borderRadius: tokens.radius.brMd,
                                border: Border.all(
                                  color: tokens.color.border,
                                  width: tokens.border.hairline,
                                ),
                              ),
                              child: SelectableText(
                                result.success
                                    ? result.output
                                    : 'Error: ${result.error}',
                                style: AppTypography.mono(
                                  color: tokens.color.textSecondary,
                                  fontSize: tokens.typeScale.mono,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  /// Resolves a button's display name from its id across all pages.
  String? _buttonName(String buttonId) {
    for (final page in ref.read(pagesProvider)) {
      for (final tile in page.tiles) {
        if (tile.button.id == buttonId) return tile.button.name;
      }
    }
    return null;
  }

  /// Shows lightweight feedback for a command result.
  ///
  /// A quick floating toast for the common case (success, no output), with a
  /// "Details" action that opens the full result sheet whenever there is
  /// output to show or an error to inspect.
  void _handleCommandResult(BuildContext context, CommandResultEvent result) {
    final tokens = context.tokens;
    final name = _buttonName(result.buttonId);
    final hasDetail = result.success ? result.output.trim().isNotEmpty : true;

    AccessibilityUtils.provideFeedback(
      result.success ? FeedbackType.light : FeedbackType.heavy,
    );

    final fg =
        result.success ? tokens.color.success : tokens.color.danger;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.color.surfaceRaised,
        duration: Duration(seconds: hasDetail ? 4 : 2),
        content: Row(
          children: [
            Container(
              width: tokens.space.sm,
              height: tokens.space.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg,
              ),
            ),
            SizedBox(width: tokens.space.md),
            Expanded(
              child: Text(
                result.success
                    ? 'Ran ${name ?? 'command'}'
                    : 'Failed: ${name ?? 'command'}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.color.textPrimary,
                      fontWeight: tokens.typeScale.wMedium,
                    ),
              ),
            ),
          ],
        ),
        action:
            hasDetail
                ? SnackBarAction(
                  label: 'Details',
                  textColor: fg,
                  onPressed: () => _showResultBottomSheet(context, result),
                )
                : null,
      ),
    );
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
    final tokens = context.tokens;

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
            showCloseIcon: true,
            closeIconColor: tokens.color.success,
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to connect to default server'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            closeIconColor: tokens.color.danger,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No default server set'),
          behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final pages = ref.watch(pagesProvider);
    final selectedPageIndex = ref.watch(selectedPageIndexProvider);
    final tokens = context.tokens;

    // Show lightweight feedback when a command result arrives.
    ref.listen<CommandResultEvent?>(commandResultProvider, (previous, next) {
      if (next != null && mounted) {
        _handleCommandResult(context, next);
      }
    });

    // Show a loading skeleton briefly after (re)connecting, until buttons land.
    ref.listen(connectionStateProvider, (previous, next) {
      if (previous?.status != ConnectionStatus.connected &&
          next.status == ConnectionStatus.connected) {
        _beginAwaitingButtons();
      }
    });
    ref.listen(pagesProvider, (previous, next) {
      if (next.isNotEmpty && _awaitingButtons) {
        _awaitTimer?.cancel();
        setState(() => _awaitingButtons = false);
      }
    });

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
        ref.read(pagesProvider.notifier).set([]);
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
            Flexible(
              child: Text(
                connectionState.connection?.name ?? 'MarcoDeck',
                style: TextStyle(fontWeight: tokens.typeScale.wBold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isConnected)
              Padding(
                padding: EdgeInsets.only(left: tokens.space.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: tokens.space.sm,
                      height: tokens.space.sm,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.color.success,
                      ),
                    ),
                    SizedBox(width: tokens.space.xs),
                    Text(
                      'Connected',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tokens.color.textMuted,
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
              style: IconButton.styleFrom(
                foregroundColor: tokens.color.textSecondary,
              ),
              onPressed: () {
                // Before refreshing, ensure connection is active
                ref.read(connectionStateProvider.notifier).requestButtons();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Buttons refreshed'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    showCloseIcon: true,
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: tokens.color.textSecondary),
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
                      leading: Icon(
                        Icons.settings_outlined,
                        color: tokens.color.textSecondary,
                      ),
                      title: const Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'servers',
                    child: ListTile(
                      leading: Icon(
                        Icons.dns_outlined,
                        color: tokens.color.textSecondary,
                      ),
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
                        color: tokens.color.textSecondary,
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
                        leading: Icon(
                          Icons.link,
                          color: tokens.color.textSecondary,
                        ),
                        title: const Text('Connect to Default'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (isConnected)
                    PopupMenuItem<String>(
                      value: 'disconnect',
                      child: ListTile(
                        leading:
                            Icon(Icons.link_off, color: tokens.color.danger),
                        title: Text(
                          'Disconnect',
                          style: TextStyle(color: tokens.color.danger),
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
                // Page name and indicator
                if (pages.isNotEmpty && selectedPageIndex < pages.length)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.space.lg,
                      tokens.space.md,
                      tokens.space.lg,
                      tokens.space.xs,
                    ),
                    child: Column(
                      children: [
                        Text(
                          pages[selectedPageIndex].name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: tokens.color.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        // Page indicator dots
                        if (pages.length > 1)
                          Padding(
                            padding: EdgeInsets.only(top: tokens.space.sm),
                            child: SmoothPageIndicator(
                              controller: _pageController,
                              count: pages.length,
                              effect: WormEffect(
                                dotHeight: tokens.space.sm,
                                dotWidth: tokens.space.sm,
                                activeDotColor: tokens.color.accent,
                                dotColor: tokens.color.border,
                                spacing: tokens.space.sm,
                                radius: tokens.space.xs,
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
                          ? (_awaitingButtons
                              ? const _SkeletonGrid()
                              : Center(
                            child: Padding(
                              padding: EdgeInsets.all(tokens.space.xxl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.grid_view_outlined,
                                    size: tokens.space.huge,
                                    color: tokens.color.textMuted,
                                  ),
                                  SizedBox(height: tokens.space.lg),
                                  Text(
                                    'No buttons configured',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: tokens.color.textSecondary,
                                        ),
                                  ),
                                  SizedBox(height: tokens.space.sm),
                                  Text(
                                    'Configure buttons in the server application',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: tokens.color.textMuted,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ))
                          : PageView.builder(
                            controller: _pageController,
                            itemCount: pages.length,
                            onPageChanged: (index) {
                              ref
                                  .read(selectedPageIndexProvider.notifier)
                                  .set(index);
                            },
                            itemBuilder: (context, index) {
                              final page = pages[index];
                              return ButtonGrid(
                                tiles: page.tiles,
                                columns: page.columns,
                                onButtonPressed: (buttonId) {
                                  // Press the button via the connection state notifier
                                  ref
                                      .read(connectionStateProvider.notifier)
                                      .pressButton(buttonId);
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
              color: tokens.color.scrim,
              alignment: Alignment.center,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: EdgeInsets.all(tokens.space.xxxl),
                padding: EdgeInsets.all(tokens.space.xxxl),
                decoration: BoxDecoration(
                  color: tokens.color.surfaceRaised,
                  borderRadius: tokens.radius.brLg,
                  border: Border.all(
                    color: tokens.color.border,
                    width: tokens.border.hairline,
                  ),
                  boxShadow: tokens.shadowMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flat monochrome status icon.
                    connectionState.status == ConnectionStatus.reconnecting
                        ? TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1500),
                            onEnd: () {
                              // Loop the animation
                            },
                            builder: (context, value, child) {
                              return Transform.rotate(
                                angle:
                                    value * 6.28318, // 2*pi for full rotation
                                child: Icon(
                                  Icons.sync,
                                  color: tokens.color.textSecondary,
                                  size: tokens.space.huge,
                                ),
                              );
                            },
                          )
                        : Icon(
                            connectionState.status == ConnectionStatus.error
                                ? Icons.error_outline
                                : Icons.wifi_find,
                            color:
                                connectionState.status == ConnectionStatus.error
                                    ? tokens.color.danger
                                    : tokens.color.textSecondary,
                            size: tokens.space.huge,
                          ),
                    SizedBox(height: tokens.space.xxl),
                    Text(
                      connectionState.status == ConnectionStatus.connecting
                          ? 'Connecting...'
                          : connectionState.status ==
                              ConnectionStatus.reconnecting
                          ? 'Reconnecting...'
                          : 'Connection Failed',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: connectionState.status ==
                                    ConnectionStatus.error
                                ? tokens.color.danger
                                : tokens.color.textPrimary,
                          ),
                    ),
                    if (connectionState.errorMessage != null) ...[
                      SizedBox(height: tokens.space.md),
                      Text(
                        connectionState.errorMessage!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: tokens.color.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    SizedBox(height: tokens.space.xxl),
                    // Action buttons
                    if (connectionState.status == ConnectionStatus.error) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .refreshConnection();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry Connection'),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.space.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.radius.brMd,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.space.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .resetErrorState();
                          },
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Dismiss'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.space.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.radius.brMd,
                            ),
                          ),
                        ),
                      ),
                    ] else if (connectionState.status ==
                        ConnectionStatus.reconnecting) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .cancelReconnection();
                            if (connectionState.connection != null) {
                              ref
                                  .read(connectionStateProvider.notifier)
                                  .connect(connectionState.connection!);
                            }
                          },
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text('Reconnect Now'),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.space.lg,
                            ),
                            foregroundColor: tokens.color.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.radius.brMd,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: tokens.space.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .cancelReconnection();
                          },
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.space.lg,
                            ),
                            foregroundColor: tokens.color.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.radius.brMd,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(connectionStateProvider.notifier)
                                .cancelConnection();
                          },
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: tokens.space.lg,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.radius.brMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoConnectionView(BuildContext context) {
    final tokens = context.tokens;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: EdgeInsets.all(tokens.space.xxxl),
        margin: EdgeInsets.all(tokens.space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space.xxl),
              child: Image.asset(
                'assets/logo.png',
                height: 100,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.devices_outlined,
                      size: tokens.space.huge + tokens.space.xxxl,
                      color: tokens.color.textMuted,
                    ),
              ),
            ),
            Text(
              'Not Connected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.color.textSecondary,
                  ),
            ),
            SizedBox(height: tokens.space.lg),
            Text(
              'Connect to a server to view and use your macro buttons',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: tokens.typeScale.wRegular,
                    color: tokens.color.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.space.xxxl),
            FilledButton.icon(
              icon: const Icon(Icons.computer),
              label: const Text('Choose Server'),
              onPressed: () => _showServerManager(context),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space.xxl,
                  vertical: tokens.space.lg,
                ),
                minimumSize: const Size(240, 0),
              ),
            ),
            SizedBox(height: tokens.space.lg),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Server'),
              onPressed: () => _showAddServerDialog(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space.xxl,
                  vertical: tokens.space.lg,
                ),
                minimumSize: const Size(240, 0),
              ),
            ),
            if (ref.read(serverConnectionsProvider.notifier).defaultServerId !=
                null) ...[
              SizedBox(height: tokens.space.xxl),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.link),
                label: const Text('Connect to Default Server'),
                onPressed: () => _connectToDefault(context),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space.xxl,
                    vertical: tokens.space.lg,
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

/// A subtly pulsing placeholder grid shown while the server's buttons are in
/// flight, so connecting feels responsive instead of flashing an empty state.
class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            width < 320
                ? 2
                : width < 480
                    ? 3
                    : width < 600
                        ? 4
                        : width < 840
                            ? 5
                            : 6;
        return GridView.builder(
          padding: EdgeInsets.all(tokens.space.lg),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: tokens.space.md,
            mainAxisSpacing: tokens.space.md,
            childAspectRatio: 1.0,
          ),
          itemCount: columns * 3,
          itemBuilder: (context, index) {
            return FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 0.7).animate(_controller),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.color.surfaceSubtle,
                  borderRadius: tokens.radius.brLg,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
