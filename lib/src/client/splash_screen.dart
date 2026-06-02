import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design.dart';
import 'buttons_screen.dart';
import 'client_providers.dart' as providers;

/// Enhanced splash screen with animations and improved UX
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates a new splash screen
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _initialized = false;
  String _statusMessage = 'Initializing...';
  double _progress = 0.0;

  late AnimationController _logoAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _logoRotationAnimation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeIn),
    );

    // Start animations
    _logoAnimationController.forward();
    _fadeAnimationController.forward();

    // Delay initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _updateProgress(double progress, String message) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusMessage = message;
      });
      // Small delay to show progress update
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _initializeApp() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Step 1: Loading saved connections
      await _updateProgress(0.2, 'Loading saved connections...');

      final defaultServer = ref
          .read(providers.serverConnectionsProvider.notifier)
          .defaultServer;

      if (defaultServer == null) {
        await _updateProgress(0.5, 'No default server configured');
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ButtonsScreen(showNoConnectionMessage: true),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
        return;
      }

      // Step 2: Connecting to server
      await _updateProgress(0.4, 'Connecting to ${defaultServer.name}...');

      debugPrint(
        'Attempting to connect to server: ${defaultServer.name} (${defaultServer.address})',
      );

      final connectionNotifier = ref.read(
        providers.connectionStateProvider.notifier,
      );

      // Step 3: Establishing connection
      await _updateProgress(0.6, 'Establishing connection...');

      // Ensure any previous connection is properly closed
      await connectionNotifier.disconnect();

      // Now attempt to connect
      final success = await connectionNotifier.connect(defaultServer);
      debugPrint('Connection attempt result: $success');

      if (success && mounted) {
        // Step 4: Loading content
        await _updateProgress(0.8, 'Loading buttons...');

        // Request buttons immediately after connection
        connectionNotifier.requestButtons();

        // Step 5: Complete
        await _updateProgress(1.0, 'Ready!');
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ButtonsScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
        return;
      } else {
        await _updateProgress(0.3, 'Connection failed - retrying...');
        debugPrint('Failed to connect to default server');
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } catch (e) {
      await _updateProgress(0.0, 'Error: ${e.toString()}');
      debugPrint('Error during initialization: $e');
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // If connection failed or error occurred, go to buttons screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ButtonsScreen(showNoConnectionMessage: true),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.color.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.color.surface, tokens.color.surfaceSubtle],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.space.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value * 3.14159,
                          child: Container(
                            width: tokens.space.huge * 2.5,
                            height: tokens.space.huge * 2.5,
                            decoration: BoxDecoration(
                              color: tokens.color.accentSubtle,
                              shape: BoxShape.circle,
                              boxShadow: tokens.shadowMd,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.devices_rounded,
                                      size: tokens.space.huge + tokens.space.md,
                                      color: tokens.color.accent,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: tokens.space.xxxl),

                  // App title with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'MarcoDeck',
                      style: textTheme.headlineMedium?.copyWith(
                        color: tokens.color.textPrimary,
                      ),
                    ),
                  ),

                  SizedBox(height: tokens.space.sm),

                  // Subtitle
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Remote Macro Control',
                      style: textTheme.bodyLarge?.copyWith(
                        color: tokens.color.textSecondary,
                        fontWeight: tokens.typeScale.wMedium,
                      ),
                    ),
                  ),

                  SizedBox(height: tokens.space.huge),

                  // Status message
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space.xl,
                        vertical: tokens.space.md,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.color.surfaceSubtle,
                        borderRadius: tokens.radius.brMd,
                        border: Border.all(
                          color: tokens.color.border,
                          width: tokens.border.hairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: tokens.icon.sm,
                            height: tokens.icon.sm,
                            child: CircularProgressIndicator(
                              strokeWidth: tokens.border.focus,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tokens.color.accent,
                              ),
                            ),
                          ),
                          SizedBox(width: tokens.space.md),
                          Flexible(
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: textTheme.bodyMedium?.copyWith(
                                color: tokens.color.textSecondary,
                                fontWeight: tokens.typeScale.wMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: tokens.space.xl),

                  // Progress bar
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: tokens.space.huge * 4,
                      height: tokens.space.xs,
                      decoration: BoxDecoration(
                        color: tokens.color.surfaceSubtle,
                        borderRadius: tokens.radius.brXs,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: _progress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                tokens.color.accent,
                                colorScheme.secondary,
                              ],
                            ),
                            borderRadius: tokens.radius.brXs,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: tokens.space.huge * 1.5),

                  // Version info
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Version 1.0.0',
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.color.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
