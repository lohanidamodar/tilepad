import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// A utility class for executing Windows-specific commands using Win32 API
class Win32Commands {
  /// Takes a screenshot of the entire screen using Win32 API
  static Future<bool> takeScreenshot({String? outputPath}) async {
    if (!Platform.isWindows) return false;

    try {
      // If no path specified, save to desktop
      final savePath =
          outputPath ??
          '${Platform.environment['USERPROFILE']}\\Desktop\\screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

      // Get desktop window handle (entire screen)
      final hwnd = GetDesktopWindow();

      // Get device context
      final hdcScreen = GetDC(hwnd);
      if (hdcScreen.address == 0) return false;

      // Get screen dimensions
      final screenWidth = GetSystemMetrics(SM_CXSCREEN);
      final screenHeight = GetSystemMetrics(SM_CYSCREEN);

      // Create compatible DC and bitmap
      final hdcMemDC = CreateCompatibleDC(hdcScreen);
      if (hdcMemDC.address == 0) {
        ReleaseDC(hwnd, hdcScreen);
        return false;
      }

      final hbmScreen = CreateCompatibleBitmap(
        hdcScreen,
        screenWidth,
        screenHeight,
      );
      if (hbmScreen.address == 0) {
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcScreen);
        return false;
      }

      // Select bitmap into compatible DC
      final hOldBitmap = SelectObject(hdcMemDC, HGDIOBJ(hbmScreen));
      if (hOldBitmap.address == 0) {
        DeleteObject(HGDIOBJ(hbmScreen));
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcScreen);
        return false;
      }

      // Copy screen to bitmap
      final success = BitBlt(
        hdcMemDC,
        0,
        0,
        screenWidth,
        screenHeight,
        hdcScreen,
        0,
        0,
        SRCCOPY,
      );

      // Get bitmap information
      final bmpInfo = calloc<BITMAPINFO>();
      bmpInfo.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
      bmpInfo.ref.bmiHeader.biWidth = screenWidth;
      bmpInfo.ref.bmiHeader.biHeight = -screenHeight; // Top-down
      bmpInfo.ref.bmiHeader.biPlanes = 1;
      bmpInfo.ref.bmiHeader.biBitCount = 32;
      bmpInfo.ref.bmiHeader.biCompression = BI_RGB;

      // Allocate memory for bitmap data
      final size = screenWidth * screenHeight * 4;
      final lpBits = calloc<Uint8>(size);

      // Get bitmap data
      final dibSuccess = GetDIBits(
        hdcMemDC,
        hbmScreen,
        0,
        screenHeight,
        lpBits,
        bmpInfo,
        DIB_RGB_COLORS,
      );

      // Save bitmap data as PNG using Dart's IO
      if (dibSuccess != 0) {
        // Clean up GDI resources first
        SelectObject(hdcMemDC, hOldBitmap);
        DeleteObject(HGDIOBJ(hbmScreen));
        DeleteDC(hdcMemDC);
        ReleaseDC(hwnd, hdcScreen);
        calloc.free(bmpInfo);
        calloc.free(lpBits);

        // Use the simpler PrintScreen approach instead
        return _takeScreenshotFallback(savePath);
      }

      // Clean up GDI resources
      SelectObject(hdcMemDC, hOldBitmap);
      DeleteObject(HGDIOBJ(hbmScreen));
      DeleteDC(hdcMemDC);
      ReleaseDC(hwnd, hdcScreen);
      calloc.free(bmpInfo);
      calloc.free(lpBits);

      return success.value && await _takeScreenshotFallback(savePath);
    } catch (e) {
      debugPrint('Error taking screenshot: $e');
      return false;
    }
  }

  /// Fallback screenshot method using PrintScreen key and clipboard
  static Future<bool> _takeScreenshotFallback(String savePath) async {
    try {
      // Send PrintScreen keystroke
      final inputs = calloc<INPUT>(2);

      // Press PrintScreen key
      inputs[0].type = INPUT_KEYBOARD;
      inputs[0].ki.wVk = VK_SNAPSHOT;
      inputs[0].ki.dwFlags = const KEYBD_EVENT_FLAGS(0); // Key down

      // Release PrintScreen key
      inputs[1].type = INPUT_KEYBOARD;
      inputs[1].ki.wVk = VK_SNAPSHOT;
      inputs[1].ki.dwFlags = KEYEVENTF_KEYUP; // Key up

      final result = SendInput(2, inputs, sizeOf<INPUT>());
      calloc.free(inputs);

      if (result.value != 2) return false;

      // Wait for screenshot to be processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Save using PowerShell (clipboard to file)
      final process = await Process.run(
        'powershell.exe',
        [
          '-command',
          '''
          Add-Type -AssemblyName System.Windows.Forms;
          Add-Type -AssemblyName System.Drawing;
          \$clipboard = [System.Windows.Forms.Clipboard]::GetImage();
          if (\$clipboard -ne \$null) {
            \$clipboard.Save("$savePath");
            Write-Output "Screenshot saved to $savePath";
            exit 0;
          } else {
            Write-Error "Failed to get image from clipboard";
            exit 1;
          }
          ''',
        ],
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      return process.exitCode == 0;
    } catch (e) {
      debugPrint('Error in screenshot fallback: $e');
      return false;
    }
  }

  /// Put the computer to sleep mode
  static bool sleep() {
    if (!Platform.isWindows) return false;

    try {
      // Use rundll32 for sleep since Win32 API is complicated
      final process = Process.runSync('rundll32.exe', [
        'powrprof.dll,SetSuspendState',
        '0',
        '1',
        '0',
      ]);
      return process.exitCode == 0;
    } catch (e) {
      debugPrint('Error putting computer to sleep: $e');
      return false;
    }
  }

  /// Shutdown the computer
  static bool shutdown() {
    if (!Platform.isWindows) return false;

    try {
      // Use the shutdown command which has proper permissions
      final process = Process.runSync('shutdown', ['/s', '/t', '0']);
      return process.exitCode == 0;
    } catch (e) {
      debugPrint('Error shutting down computer: $e');
      return false;
    }
  }

  /// Restart the computer
  static bool restart() {
    if (!Platform.isWindows) return false;

    try {
      // Use the shutdown command with restart flag
      final process = Process.runSync('shutdown', ['/r', '/t', '0']);
      return process.exitCode == 0;
    } catch (e) {
      debugPrint('Error restarting computer: $e');
      return false;
    }
  }

  /// Lock the workstation
  static bool lockWorkstation() {
    if (!Platform.isWindows) return false;

    try {
      final result = LockWorkStation();
      return result.value;
    } catch (e) {
      debugPrint('Error locking workstation: $e');
      return false;
    }
  }

  /// Adjust the system volume (up, down, or mute)
  static bool adjustVolume(String action) {
    if (!Platform.isWindows) return false;

    try {
      final inputs = calloc<INPUT>(2);
      VIRTUAL_KEY vk;

      switch (action.toLowerCase()) {
        case 'up':
          vk = VK_VOLUME_UP;
          break;
        case 'down':
          vk = VK_VOLUME_DOWN;
          break;
        case 'mute':
          vk = VK_VOLUME_MUTE;
          break;
        default:
          calloc.free(inputs);
          return false;
      }

      // Press key
      inputs[0].type = INPUT_KEYBOARD;
      inputs[0].ki.wVk = vk;
      inputs[0].ki.dwFlags = const KEYBD_EVENT_FLAGS(0); // Key down

      // Release key
      inputs[1].type = INPUT_KEYBOARD;
      inputs[1].ki.wVk = vk;
      inputs[1].ki.dwFlags = KEYEVENTF_KEYUP; // Key up

      final result = SendInput(2, inputs, sizeOf<INPUT>());
      calloc.free(inputs);

      return result.value == 2;
    } catch (e) {
      debugPrint('Error adjusting volume: $e');
      return false;
    }
  }
}
