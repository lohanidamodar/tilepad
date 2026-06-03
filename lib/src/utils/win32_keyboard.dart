import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// A utility class for simulating keyboard input on Windows using Win32 APIs
class Win32Keyboard {
  /// Simulates a keystroke with optional modifier keys using Win32 API
  ///
  /// This provides a more reliable alternative to PowerShell SendKeys
  static bool sendKeystroke(String key, List<String> modifiers) {
    try {
      // Map of virtual key codes for modifiers
      final modifierKeyCodes = {
        'ctrl': VK_CONTROL,
        'alt': VK_MENU,
        'shift': VK_SHIFT,
        'win': VK_LWIN,
        'meta': VK_LWIN,
      };

      // Map for common keys to virtual key codes
      final keyCodes = {
        'enter': VK_RETURN,
        'tab': VK_TAB,
        'esc': VK_ESCAPE,
        'escape': VK_ESCAPE,
        'space': VK_SPACE,
        'backspace': VK_BACK,
        'delete': VK_DELETE,
        'home': VK_HOME,
        'end': VK_END,
        'pageup': VK_PRIOR,
        'pagedown': VK_NEXT,
        'up': VK_UP,
        'down': VK_DOWN,
        'left': VK_LEFT,
        'right': VK_RIGHT,
        'f1': VK_F1,
        'f2': VK_F2,
        'f3': VK_F3,
        'f4': VK_F4,
        'f5': VK_F5,
        'f6': VK_F6,
        'f7': VK_F7,
        'f8': VK_F8,
        'f9': VK_F9,
        'f10': VK_F10,
        'f11': VK_F11,
        'f12': VK_F12,
        // Media transport + volume keys (used by ActionType.mediaKey).
        'media_playpause': VK_MEDIA_PLAY_PAUSE,
        'media_next': VK_MEDIA_NEXT_TRACK,
        'media_previous': VK_MEDIA_PREV_TRACK,
        'media_stop': VK_MEDIA_STOP,
        'media_mute': VK_VOLUME_MUTE,
        'media_volumeup': VK_VOLUME_UP,
        'media_volumedown': VK_VOLUME_DOWN,
        '0': 0x30,
        '1': 0x31,
        '2': 0x32,
        '3': 0x33,
        '4': 0x34,
        '5': 0x35,
        '6': 0x36,
        '7': 0x37,
        '8': 0x38,
        '9': 0x39,
        'a': 0x41,
        'b': 0x42,
        'c': 0x43,
        'd': 0x44,
        'e': 0x45,
        'f': 0x46,
        'g': 0x47,
        'h': 0x48,
        'i': 0x49,
        'j': 0x4A,
        'k': 0x4B,
        'l': 0x4C,
        'm': 0x4D,
        'n': 0x4E,
        'o': 0x4F,
        'p': 0x50,
        'q': 0x51,
        'r': 0x52,
        's': 0x53,
        't': 0x54,
        'u': 0x55,
        'v': 0x56,
        'w': 0x57,
        'x': 0x58,
        'y': 0x59,
        'z': 0x5A,
      };

      // Get the virtual key code for the main key
      int keyCode;
      final keyLower = key.toLowerCase();

      if (keyCodes.containsKey(keyLower)) {
        keyCode = keyCodes[keyLower]!;
      } else if (key.length == 1 &&
          key[0].codeUnitAt(0) >= 32 &&
          key[0].codeUnitAt(0) <= 126) {
        // ASCII characters - use VkKeyScan for characters not in our map
        final charCode = key[0].toUpperCase().codeUnitAt(0);
        // Use the VkKeyScan function from win32 package
        final scanCode = VkKeyScan(charCode);
        keyCode = scanCode & 0xFF;
      } else {
        debugPrint('Unsupported key: $key');
        return false;
      }

      // Prepare INPUT structures for sending keystrokes
      final inputs = calloc<INPUT>(modifiers.length * 2 + 2);
      int inputIndex = 0;

      // Press all modifier keys
      for (final modifier in modifiers) {
        if (modifierKeyCodes.containsKey(modifier.toLowerCase())) {
          final modifierCode = modifierKeyCodes[modifier.toLowerCase()]!;
          inputs[inputIndex].type = INPUT_KEYBOARD;
          inputs[inputIndex].ki.wVk = modifierCode;
          inputs[inputIndex].ki.dwFlags = const KEYBD_EVENT_FLAGS(0); // Key down
          inputIndex++;
        }
      }

      // Press the main key
      inputs[inputIndex].type = INPUT_KEYBOARD;
      inputs[inputIndex].ki.wVk = VIRTUAL_KEY(keyCode);
      inputs[inputIndex].ki.dwFlags = const KEYBD_EVENT_FLAGS(0); // Key down
      inputIndex++;

      // Release the main key
      inputs[inputIndex].type = INPUT_KEYBOARD;
      inputs[inputIndex].ki.wVk = VIRTUAL_KEY(keyCode);
      inputs[inputIndex].ki.dwFlags = KEYEVENTF_KEYUP; // Key up
      inputIndex++;

      // Release all modifier keys
      for (final modifier in modifiers.reversed) {
        if (modifierKeyCodes.containsKey(modifier.toLowerCase())) {
          final modifierCode = modifierKeyCodes[modifier.toLowerCase()]!;
          inputs[inputIndex].type = INPUT_KEYBOARD;
          inputs[inputIndex].ki.wVk = modifierCode;
          inputs[inputIndex].ki.dwFlags = KEYEVENTF_KEYUP; // Key up
          inputIndex++;
        }
      }

      // Send the input
      final result = SendInput(inputIndex, inputs, sizeOf<INPUT>());

      // Free the allocated memory
      calloc.free(inputs);

      return result.value == inputIndex;
    } catch (e) {
      debugPrint('Error sending Win32 keystroke: $e');
      return false;
    }
  }

  /// Types arbitrary [text] into the focused window using Win32 SendInput with
  /// Unicode events, so any character can be sent regardless of layout.
  static bool typeText(String text) {
    if (text.isEmpty) return true;
    try {
      // One key-down + key-up event per UTF-16 code unit.
      final units = text.codeUnits;
      final inputs = calloc<INPUT>(units.length * 2);
      var index = 0;
      for (final unit in units) {
        // Key down
        inputs[index].type = INPUT_KEYBOARD;
        inputs[index].ki.wVk = const VIRTUAL_KEY(0);
        inputs[index].ki.wScan = unit;
        inputs[index].ki.dwFlags = KEYEVENTF_UNICODE;
        index++;
        // Key up
        inputs[index].type = INPUT_KEYBOARD;
        inputs[index].ki.wVk = const VIRTUAL_KEY(0);
        inputs[index].ki.wScan = unit;
        inputs[index].ki.dwFlags = KEYBD_EVENT_FLAGS(
          KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
        );
        index++;
      }

      final result = SendInput(index, inputs, sizeOf<INPUT>());
      calloc.free(inputs);
      return result.value == index;
    } catch (e) {
      debugPrint('Error typing text via Win32: $e');
      return false;
    }
  }
}
