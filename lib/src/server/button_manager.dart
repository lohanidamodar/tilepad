import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/button.dart';

/// Service responsible for managing button configurations on the server
class ButtonManager {
  /// List of all available buttons
  List<Button> _buttons = [];

  /// Path to the buttons configuration file
  String? _configPath;

  /// Getter for the buttons
  List<Button> get buttons => List.unmodifiable(_buttons);

  /// Initializes the button manager
  Future<void> initialize() async {
    await _loadConfig();

    // If no buttons were loaded, create some default ones
    if (_buttons.isEmpty) {
      _createDefaultButtons();
      await saveConfig();
    }
  }

  /// Loads button configurations from disk
  Future<void> _loadConfig() async {
    try {
      final directory = await _getConfigDirectory();
      final file = File('${directory.path}/buttons.json');
      _configPath = file.path;

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);

        _buttons = jsonList.map((json) => Button.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading button configuration: $e');
      _buttons = [];
    }
  }

  /// Saves button configurations to disk
  Future<void> saveConfig() async {
    try {
      if (_configPath == null) {
        final directory = await _getConfigDirectory();
        _configPath = '${directory.path}/buttons.json';
      }

      final file = File(_configPath!);
      final jsonList = _buttons.map((button) => button.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving button configuration: $e');
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

  /// Adds a new button
  void addButton(Button button) {
    _buttons.add(button);
    saveConfig();
  }

  /// Updates an existing button
  bool updateButton(Button updatedButton) {
    final index = _buttons.indexWhere((b) => b.id == updatedButton.id);
    if (index != -1) {
      _buttons[index] = updatedButton;
      saveConfig();
      return true;
    }
    return false;
  }

  /// Deletes a button
  bool deleteButton(String id) {
    final previousLength = _buttons.length;
    _buttons.removeWhere((button) => button.id == id);
    final deleted = _buttons.length < previousLength;
    if (deleted) {
      saveConfig();
    }
    return deleted;
  }

  /// Creates default buttons
  void _createDefaultButtons() {
    _buttons = [
      Button(
        name: 'Open Browser',
        iconName: FontAwesomeIcons.globe.codePoint.toString(),
        command:
            Platform.isWindows
                ? 'start chrome'
                : (Platform.isMacOS
                    ? 'open -a "Google Chrome"'
                    : 'google-chrome'),
      ),
      Button(
        name: 'Open Notepad',
        iconName: FontAwesomeIcons.noteSticky.codePoint.toString(),
        command:
            Platform.isWindows
                ? 'notepad'
                : (Platform.isMacOS ? 'open -a TextEdit' : 'gedit'),
        color: '#4CAF50',
      ),
      Button(
        name: 'System Info',
        iconName: FontAwesomeIcons.computer.codePoint.toString(),
        command:
            Platform.isWindows ? 'systeminfo' : 'uname -a && lsb_release -a',
        color: '#FFC107',
      ),
    ];
  }
}
