import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/button.dart';

/// Dialog for editing a macro button's properties
class ButtonEditorDialog extends StatefulWidget {
  /// The button to edit, null if creating a new button
  final Button? button;

  /// Creates a new button editor dialog
  const ButtonEditorDialog({super.key, this.button});

  @override
  State<ButtonEditorDialog> createState() => _ButtonEditorDialogState();
}

class _ButtonEditorDialogState extends State<ButtonEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commandController = TextEditingController();
  String _selectedIcon = FontAwesomeIcons.lightbulb.codePoint.toString();
  String _selectedColor = '#4285F4';

  final List<Color> _presetColors = [
    const Color(0xFF4285F4), // Google Blue
    const Color(0xFF34A853), // Google Green
    const Color(0xFFFBBC05), // Google Yellow
    const Color(0xFFEA4335), // Google Red
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue Grey
  ];

  final List<IconData> _presetIcons = [
    FontAwesomeIcons.lightbulb,
    FontAwesomeIcons.computer,
    FontAwesomeIcons.play,
    FontAwesomeIcons.stop,
    FontAwesomeIcons.volumeHigh,
    FontAwesomeIcons.volumeXmark,
    FontAwesomeIcons.display,
    FontAwesomeIcons.fire,
    FontAwesomeIcons.powerOff,
    FontAwesomeIcons.windowRestore,
    FontAwesomeIcons.folderOpen,
    FontAwesomeIcons.terminal,
    FontAwesomeIcons.circlePlay,
    FontAwesomeIcons.clockRotateLeft,
    FontAwesomeIcons.desktop,
    FontAwesomeIcons.keyboard,
    FontAwesomeIcons.cameraRetro,
    FontAwesomeIcons.solidEnvelope,
    FontAwesomeIcons.penToSquare,
    FontAwesomeIcons.code,
  ];

  @override
  void initState() {
    super.initState();

    // Initialize form with existing button data if editing
    if (widget.button != null) {
      _nameController.text = widget.button!.name;
      _commandController.text = widget.button!.command;
      _selectedIcon = widget.button!.iconName;
      _selectedColor = widget.button!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  /// Saves the button and returns it
  void _saveButton() {
    if (_formKey.currentState!.validate()) {
      final button = Button(
        id: widget.button?.id,
        name: _nameController.text,
        iconName: _selectedIcon,
        command: _commandController.text,
        color: _selectedColor,
      );

      Navigator.of(context).pop(button);
    }
  }

  /// Converts a color to a hex string
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }

  /// Converts a hex string to a Color
  Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  /// Handles icon selection and stores the code point
  void _selectIcon(IconData icon) {
    setState(() {
      // Store just the code point as a string
      _selectedIcon = icon.codePoint.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.button == null ? 'Create Button' : 'Edit Button',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Button Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commandController,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'e.g., notepad.exe or python script.py',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a command';
                  }
                  return null;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Button Color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetColors.length,
                  itemBuilder: (context, index) {
                    final color = _presetColors[index];
                    final colorHex = _colorToHex(color);
                    final isSelected = colorHex == _selectedColor;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = colorHex;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border:
                                isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Button Icon',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                  ),
                  itemCount: _presetIcons.length,
                  itemBuilder: (context, index) {
                    final icon = _presetIcons[index];
                    final iconString = icon.codePoint.toString();
                    final isSelected = iconString == _selectedIcon;

                    return GestureDetector(
                      onTap: () {
                        _selectIcon(icon);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? _hexToColor(_selectedColor)
                                  : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveButton,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
