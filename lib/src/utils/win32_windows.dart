import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import '../models/window_info.dart';

/// Collects results during an [EnumWindows] pass. `Pointer.fromFunction`
/// requires a top-level/static callback, so the accumulator lives here too.
final List<WindowInfo> _enumResults = [];

int _enumWindowsProc(Pointer hwndPtr, int lParam) {
  final hwnd = HWND(hwndPtr);

  // Only real, focusable application windows.
  if (!IsWindowVisible(hwnd)) return TRUE;
  if (!IsWindowEnabled(hwnd)) return TRUE;

  // Skip tool windows and owned helper windows (dialogs, popups), which are
  // not the kind of window a user means to "focus".
  final exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE).value;
  if ((exStyle & WS_EX_TOOLWINDOW) != 0) return TRUE;
  final owner = GetWindow(hwnd, GW_OWNER).value;
  if (owner.address != 0 && (exStyle & WS_EX_APPWINDOW) == 0) return TRUE;

  final length = GetWindowTextLength(hwnd).value;
  if (length == 0) return TRUE;

  final buffer = wsalloc(length + 1);
  GetWindowText(hwnd, buffer, length + 1);
  final title = buffer.toDartString();
  free(buffer);

  if (title.trim().isNotEmpty) {
    _enumResults.add(
      WindowInfo(id: hwndPtr.address.toString(), title: title),
    );
  }
  return TRUE;
}

/// Win32 helpers for listing and activating top-level windows.
class Win32Windows {
  /// Lists the currently open, visible, focusable top-level windows.
  static List<WindowInfo> list() {
    _enumResults.clear();
    try {
      EnumWindows(
        Pointer.fromFunction<WNDENUMPROC>(_enumWindowsProc, 0),
        LPARAM(0),
      );
    } catch (e) {
      debugPrint('Error enumerating windows: $e');
    }
    // De-duplicate by title (keep first) and sort case-insensitively.
    final seen = <String>{};
    return _enumResults.where((w) => seen.add(w.title.toLowerCase())).toList()
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  }

  /// Brings the window with the given [handle] (its address as a string) to
  /// the foreground, restoring it first if minimized.
  static bool activate(String handle) {
    final address = int.tryParse(handle);
    if (address == null || address == 0) return false;
    try {
      final hwnd = HWND(Pointer.fromAddress(address));
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      }

      // A background process can't normally steal focus, so briefly attach to
      // the current foreground window's input thread to allow it.
      final foreground = GetForegroundWindow();
      final targetThread = GetWindowThreadProcessId(hwnd, nullptr);
      final foregroundThread = GetWindowThreadProcessId(foreground, nullptr);
      final attached =
          foregroundThread != targetThread &&
          AttachThreadInput(foregroundThread, targetThread, true);

      BringWindowToTop(hwnd);
      ShowWindow(hwnd, SW_SHOW);
      final ok = SetForegroundWindow(hwnd);

      if (attached) {
        AttachThreadInput(foregroundThread, targetThread, false);
      }

      // SetForegroundWindow can report false from a background process even
      // when it actually succeeded, so trust whether the window is now in the
      // foreground.
      return ok || GetForegroundWindow().address == hwnd.address;
    } catch (e) {
      debugPrint('Error activating window: $e');
      return false;
    }
  }
}
