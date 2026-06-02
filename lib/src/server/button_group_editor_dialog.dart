import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';

import '../design/design.dart';
import '../models/button_group.dart';

/// Dialog for creating or editing button groups
class ButtonGroupEditorDialog extends StatefulWidget {
  /// The button group to edit, or null for creating a new group
  final ButtonGroup? group;

  /// Creates a button group editor dialog
  const ButtonGroupEditorDialog({super.key, this.group});

  @override
  State<ButtonGroupEditorDialog> createState() =>
      _ButtonGroupEditorDialogState();
}

class _ButtonGroupEditorDialogState extends State<ButtonGroupEditorDialog> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  late Color _groupColor;
  bool _groupColorInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with existing group data or defaults
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    if (widget.group?.color != null) {
      _groupColor =
          Color(int.parse(widget.group!.color.replaceFirst('#', '0xff')));
      _groupColorInitialized = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default the swatch to the themed accent when creating a new group.
    if (!_groupColorInitialized) {
      _groupColor = context.tokens.color.accent;
      _groupColorInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.group == null ? 'Create Button Group' : 'Edit Button Group',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'My Button Group',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
              autofocus: true,
            ),
            SizedBox(height: context.tokens.space.lg),
            Text('Group Color'),
            SizedBox(height: context.tokens.space.sm),
            GestureDetector(
              onTap: _showColorPicker,
              child: Container(
                width: context.tokens.icon.xl + context.tokens.space.lg,
                height: context.tokens.icon.xl + context.tokens.space.lg,
                decoration: BoxDecoration(
                  color: _groupColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.tokens.color.border,
                    width: context.tokens.border.hairline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _saveGroup, child: const Text('SAVE')),
      ],
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _groupColor,
              onColorChanged: (Color color) {
                setState(() => _groupColor = color);
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _saveGroup() {
    if (_formKey.currentState!.validate()) {
      final colorHex =
          '#${_groupColor.toARGB32().toRadixString(16).substring(2)}';

      final group = (widget.group ??
              ButtonGroup(
                id: const Uuid().v4(),
                name: '',
                color: '',
                buttons: [],
              ))
          .copyWith(name: _nameController.text, color: colorHex);

      Navigator.of(context).pop(group);
    }
  }
}
