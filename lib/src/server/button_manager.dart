import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picons/picons.dart';

import '../models/button.dart';

/// Service responsible for managing button configurations on the server
class ButtonManager {
  /// List of all available pages with buttons
  List<Page> _pages = [];

  /// Path to the configuration file
  String? _configPath;

  /// Getter for all pages
  List<Page> get pages => List.unmodifiable(_pages);

  /// Getter for all buttons (flattened from all pages)
  List<Button> get buttons {
    final allButtons = <Button>[];
    for (final page in _pages) {
      allButtons.addAll(page.buttons);
    }
    return List.unmodifiable(allButtons);
  }

  /// Initializes the button manager
  Future<void> initialize() async {
    await _loadConfig();

    // If no pages were loaded, create a default page with some buttons
    if (_pages.isEmpty) {
      _createDefaultPages();
      await saveConfig();
    }
  }

  /// Loads configuration from disk
  Future<void> _loadConfig() async {
    try {
      final directory = await _getConfigDirectory();
      final file = File('${directory.path}/pages.json');
      _configPath = file.path;

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);

        _pages = jsonList.map((json) => Page.fromJson(json)).toList();
      } else {
        // Try to load from the old format (buttons.json) for backward compatibility
        final oldConfigFile = File('${directory.path}/buttons.json');
        if (await oldConfigFile.exists()) {
          final String contents = await oldConfigFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(contents);

          final buttons =
              jsonList.map((json) => Button.fromJson(json)).toList();

          // Convert old format to new format by creating a default page with the buttons
          if (buttons.isNotEmpty) {
            _pages = [Page(name: 'Main Page', buttons: buttons)];
            // Save in the new format and delete the old file
            await saveConfig();
            await oldConfigFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading configuration: $e');
      _pages = [];
    }
  }

  /// Saves configuration to disk
  Future<void> saveConfig() async {
    try {
      if (_configPath == null) {
        final directory = await _getConfigDirectory();
        _configPath = '${directory.path}/pages.json';
      }

      final file = File(_configPath!);
      final jsonList = _pages.map((page) => page.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving configuration: $e');
    }
  }

  /// Gets the configuration directory based on the platform
  Future<Directory> _getConfigDirectory() async {
    late final Directory directory;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      directory = await getApplicationSupportDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    // Create marco_deck subdirectory
    final marcoDeckDir = Directory('${directory.path}/marco_deck');
    if (!await marcoDeckDir.exists()) {
      await marcoDeckDir.create(recursive: true);
    }

    return marcoDeckDir;
  }

  /// Gets a page by its ID
  Page? getPage(String id) {
    try {
      return _pages.firstWhere((page) => page.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Gets a button by its ID (searches all pages)
  Button? getButton(String id) {
    for (final page in _pages) {
      try {
        final button = page.buttons.firstWhere((button) => button.id == id);
        return button;
      } catch (e) {
        // Button not found in this page, continue to next page
      }
    }
    return null;
  }

  /// Gets the page that contains a specific button
  Page? getPageContainingButton(String buttonId) {
    for (final page in _pages) {
      if (page.buttons.any((button) => button.id == buttonId)) {
        return page;
      }
    }
    return null;
  }

  /// Adds a new page
  void addPage(Page page) {
    _pages.add(page);
    saveConfig();
  }

  /// Updates an existing page
  bool updatePage(Page updatedPage) {
    final index = _pages.indexWhere((p) => p.id == updatedPage.id);
    if (index != -1) {
      _pages[index] = updatedPage;
      saveConfig();
      return true;
    }
    return false;
  }

  /// Deletes a page
  bool deletePage(String id) {
    final previousLength = _pages.length;
    _pages.removeWhere((page) => page.id == id);
    final deleted = _pages.length < previousLength;
    if (deleted) {
      saveConfig();
    }
    return deleted;
  }

  /// Reorders pages
  void reorderPages(List<Page> newOrder) {
    // Update the order property of each page based on its position in the new order
    for (int i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
    }

    // Replace the current pages list with the new ordered list
    _pages = List.from(newOrder);
    saveConfig();
  }

  /// Adds a new button to a specific page
  bool addButton(Button button, String pageId) {
    final page = getPage(pageId);
    if (page != null) {
      page.buttons.add(button);
      saveConfig();
      return true;
    }
    return false;
  }

  /// Updates an existing button
  bool updateButton(Button updatedButton) {
    for (final page in _pages) {
      final index = page.buttons.indexWhere((b) => b.id == updatedButton.id);
      if (index != -1) {
        page.buttons[index] = updatedButton;
        saveConfig();
        return true;
      }
    }
    return false;
  }

  /// Deletes a button
  bool deleteButton(String id) {
    bool deleted = false;
    for (final page in _pages) {
      final previousLength = page.buttons.length;
      page.buttons.removeWhere((button) => button.id == id);
      if (page.buttons.length < previousLength) {
        deleted = true;
        break;
      }
    }

    if (deleted) {
      saveConfig();
    }
    return deleted;
  }

  /// Moves a button from one page to another
  bool moveButton(String buttonId, String targetPageId) {
    // Find the button and its current page
    Button? button;
    Page? sourcePage;

    for (final page in _pages) {
      final index = page.buttons.indexWhere((b) => b.id == buttonId);
      if (index != -1) {
        button = page.buttons[index];
        sourcePage = page;
        page.buttons.removeAt(index);
        break;
      }
    }

    if (button == null || sourcePage == null) {
      return false;
    }

    // Find the target page and add the button
    final targetPage = getPage(targetPageId);
    if (targetPage != null) {
      targetPage.buttons.add(button);
      saveConfig();
      return true;
    }

    // If target page not found, put the button back in its original page
    sourcePage.buttons.add(button);
    return false;
  }

  /// Creates default pages with buttons
  void _createDefaultPages() {
    final defaultButtons = [
      Button(
        name: 'Open Browser',
        iconName: PiconsRegular.globe.codePoint.toString(),
        command:
            Platform.isWindows
                ? 'start chrome'
                : (Platform.isMacOS
                    ? 'open -a "Google Chrome"'
                    : 'google-chrome'),
      ),
      Button(
        name: 'Open Notepad',
        iconName: PiconsRegular.note.codePoint.toString(),
        command:
            Platform.isWindows
                ? 'notepad'
                : (Platform.isMacOS ? 'open -a TextEdit' : 'gedit'),
        color: '#4CAF50',
      ),
    ];

    final systemButtons = [
      Button(
        name: 'System Info',
        iconName: PiconsRegular.desktop.codePoint.toString(),
        command:
            Platform.isWindows ? 'systeminfo' : 'uname -a && lsb_release -a',
        color: '#FFC107',
      ),
      Button(
        name: 'Power Options',
        iconName: PiconsRegular.power.codePoint.toString(),
        type: ButtonType.commandPreset,
        command:
            Platform.isWindows
                ? 'shutdown /s /t 0'
                : (Platform.isMacOS
                    ? 'sudo shutdown -h now'
                    : 'sudo shutdown -h now'),
        color: '#F44336',
      ),
    ];

    _pages = [
      Page(name: 'Applications', order: 0, buttons: defaultButtons),
      Page(name: 'System', order: 1, buttons: systemButtons),
    ];
  }
}
