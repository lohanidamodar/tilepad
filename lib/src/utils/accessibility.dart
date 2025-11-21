import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accessibility utilities for the MarcoDeck application
class AccessibilityUtils {
  /// Announce a message to screen readers
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Provide haptic feedback based on the action type
  static void provideFeedback(FeedbackType type) {
    switch (type) {
      case FeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case FeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case FeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case FeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case FeedbackType.vibrate:
        HapticFeedback.vibrate();
        break;
    }
  }

  /// Get appropriate semantic label for button states
  static String getButtonStateLabel(bool isConnected, bool isPressed) {
    if (isPressed) {
      return 'Button activated';
    } else if (isConnected) {
      return 'Button ready, double tap to activate';
    } else {
      return 'Button unavailable, not connected to server';
    }
  }

  /// Get semantic label for connection status
  static String getConnectionStatusLabel(
    bool isConnected,
    bool isReconnecting,
  ) {
    if (isReconnecting) {
      return 'Reconnecting to server';
    } else if (isConnected) {
      return 'Connected to server';
    } else {
      return 'Disconnected from server';
    }
  }

  /// Create a semantic widget with proper labels and hints
  static Widget semanticWrapper({
    required Widget child,
    required String label,
    String? hint,
    String? value,
    bool? isButton,
    bool? isEnabled,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton ?? false,
      enabled: isEnabled ?? true,
      onTap: onTap,
      child: child,
    );
  }
}

/// Feedback types for haptic feedback
enum FeedbackType { light, medium, heavy, selection, vibrate }

/// High contrast theme extension
extension HighContrastTheme on ThemeData {
  /// Create a high contrast version of the current theme
  ThemeData toHighContrast() {
    final isLight = brightness == Brightness.light;

    return copyWith(
      colorScheme:
          isLight
              ? const ColorScheme.highContrastLight()
              : const ColorScheme.highContrastDark(),
      // Increase text contrast
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: isLight ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: isLight ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Increase button contrast
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLight ? Colors.black : Colors.white,
          foregroundColor: isLight ? Colors.white : Colors.black,
          side: BorderSide(
            color: isLight ? Colors.black : Colors.white,
            width: 2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isLight ? Colors.black : Colors.white,
          foregroundColor: isLight ? Colors.white : Colors.black,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isLight ? Colors.black : Colors.white,
            width: 3,
          ),
          foregroundColor: isLight ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

/// Accessibility settings provider
/// Settings for accessibility options
class AccessibilitySettings extends Notifier<AccessibilityState> {
  @override
  AccessibilityState build() {
    return AccessibilityState();
  }

  void toggleHighContrast() {
    state = state.copyWith(highContrastMode: !state.highContrastMode);
  }

  void toggleReduceAnimations() {
    state = state.copyWith(reduceAnimations: !state.reduceAnimations);
  }

  void setTextScale(double scale) {
    state = state.copyWith(textScale: scale.clamp(0.8, 2.0));
  }
}

/// State class for accessibility settings
class AccessibilityState {
  final bool highContrastMode;
  final bool reduceAnimations;
  final double textScale;

  AccessibilityState({
    this.highContrastMode = false,
    this.reduceAnimations = false,
    this.textScale = 1.0,
  });

  Duration get animationDuration {
    return reduceAnimations
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 300);
  }

  AccessibilityState copyWith({
    bool? highContrastMode,
    bool? reduceAnimations,
    double? textScale,
  }) {
    return AccessibilityState(
      highContrastMode: highContrastMode ?? this.highContrastMode,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      textScale: textScale ?? this.textScale,
    );
  }
}

/// Accessible button widget with proper semantics
class AccessibleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String label;
  final String? hint;
  final ButtonStyle? style;
  final bool enabled;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.hint,
    this.style,
    this.enabled = true,
  });

  @override
  State<AccessibleButton> createState() => _AccessibleButtonState();
}

class _AccessibleButtonState extends State<AccessibleButton> {
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      hint: widget.hint,
      button: true,
      enabled: widget.enabled,
      focusable: true,
      focused: _isFocused,
      onTap: widget.enabled ? widget.onPressed : null,
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
          });
        },
        child: GestureDetector(
          onTapDown:
              widget.enabled
                  ? (_) {
                    setState(() {
                      _isPressed = true;
                    });
                    AccessibilityUtils.provideFeedback(FeedbackType.light);
                  }
                  : null,
          onTapUp:
              widget.enabled
                  ? (_) {
                    setState(() {
                      _isPressed = false;
                    });
                    widget.onPressed?.call();
                  }
                  : null,
          onTapCancel: () {
            setState(() {
              _isPressed = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              border:
                  _isFocused
                      ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedScale(
              scale: _isPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
