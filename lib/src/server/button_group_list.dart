import 'package:flutter/material.dart';

import '../design/design.dart';
import '../models/button.dart';
import '../models/button_group.dart';
import '../utils/macro_icons.dart';
import 'button_editor_dialog.dart';
import 'button_group_editor_dialog.dart';

/// Widget for managing button groups and their buttons
class ButtonGroupList extends StatefulWidget {
  /// Initial list of button groups
  final List<ButtonGroup> buttonGroups;

  /// Callback when groups are updated
  final Function(List<ButtonGroup> groups) onGroupsUpdated;

  /// Creates a button group list widget
  const ButtonGroupList({
    super.key,
    required this.buttonGroups,
    required this.onGroupsUpdated,
  });

  @override
  State<ButtonGroupList> createState() => _ButtonGroupListState();
}

class _ButtonGroupListState extends State<ButtonGroupList> {
  late List<ButtonGroup> _buttonGroups;

  @override
  void initState() {
    super.initState();
    _buttonGroups = List.from(widget.buttonGroups);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Button Groups',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Group'),
              onPressed: _addGroup,
            ),
          ],
        ),
        SizedBox(height: context.tokens.space.lg),
        if (_buttonGroups.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.tokens.space.lg),
              child: const Text(
                'No button groups yet. Create one to get started.',
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _buttonGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = _buttonGroups[groupIndex];
                return _buildGroup(group, groupIndex);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGroup(ButtonGroup group, int groupIndex) {
    final colorValue = int.parse(group.color.replaceFirst('#', '0xff'));
    final groupColor = Color(colorValue);

    return Card(
      margin: EdgeInsets.symmetric(vertical: context.tokens.space.sm),
      child: ExpansionTile(
        leading: Container(
          width: context.tokens.icon.xl,
          height: context.tokens.icon.xl,
          decoration: BoxDecoration(color: groupColor, shape: BoxShape.circle),
        ),
        title: Text(group.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Group',
              onPressed: () => _editGroup(group, groupIndex),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Group',
              onPressed: () => _deleteGroup(groupIndex),
            ),
            SizedBox(width: context.tokens.space.xxxl), // Space for expansion icon
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.tokens.space.lg,
              vertical: context.tokens.space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Buttons',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Button'),
                      onPressed: () => _addButton(groupIndex),
                    ),
                  ],
                ),
                SizedBox(height: context.tokens.space.sm),
                if (group.buttons.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(context.tokens.space.sm),
                    child: const Text('No buttons in this group.'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.buttons.length,
                    itemBuilder: (context, buttonIndex) {
                      final button = group.buttons[buttonIndex];
                      return ListTile(
                        leading:
                            button.iconName.isNotEmpty
                                ? Icon(MacroIcons.resolve(button.iconName))
                                : const Icon(Icons.touch_app),
                        title: Text(button.name),
                        subtitle: Text(button.command),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed:
                                  () => _editButton(
                                    button,
                                    groupIndex,
                                    buttonIndex,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed:
                                  () => _deleteButton(groupIndex, buttonIndex),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addGroup() async {
    final result = await showDialog<ButtonGroup>(
      context: context,
      builder: (context) => const ButtonGroupEditorDialog(),
    );

    if (result != null) {
      setState(() {
        _buttonGroups.add(result);
        _notifyGroupsChanged();
      });
    }
  }

  Future<void> _editGroup(ButtonGroup group, int groupIndex) async {
    final result = await showDialog<ButtonGroup>(
      context: context,
      builder: (context) => ButtonGroupEditorDialog(group: group),
    );

    if (result != null) {
      setState(() {
        _buttonGroups[groupIndex] = result;
        _notifyGroupsChanged();
      });
    }
  }

  void _deleteGroup(int groupIndex) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: const Text(
              'Are you sure you want to delete this group and all its buttons?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _buttonGroups.removeAt(groupIndex);
                    _notifyGroupsChanged();
                  });
                },
                child: const Text('DELETE'),
              ),
            ],
          ),
    );
  }

  Future<void> _addButton(int groupIndex) async {
    final result = await showDialog<Button>(
      context: context,
      builder: (context) => const ButtonEditorDialog(),
    );

    if (result != null) {
      setState(() {
        final updatedGroup = _buttonGroups[groupIndex].copyWith(
          buttons: [..._buttonGroups[groupIndex].buttons, result],
        );
        _buttonGroups[groupIndex] = updatedGroup;
        _notifyGroupsChanged();
      });
    }
  }

  Future<void> _editButton(
    Button button,
    int groupIndex,
    int buttonIndex,
  ) async {
    final result = await showDialog<Button>(
      context: context,
      builder: (context) => ButtonEditorDialog(button: button),
    );

    if (result != null) {
      setState(() {
        final updatedButtons = List<Button>.from(
          _buttonGroups[groupIndex].buttons,
        );
        updatedButtons[buttonIndex] = result;

        _buttonGroups[groupIndex] = _buttonGroups[groupIndex].copyWith(
          buttons: updatedButtons,
        );

        _notifyGroupsChanged();
      });
    }
  }

  void _deleteButton(int groupIndex, int buttonIndex) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Button'),
            content: const Text('Are you sure you want to delete this button?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    final updatedButtons = List<Button>.from(
                      _buttonGroups[groupIndex].buttons,
                    );
                    updatedButtons.removeAt(buttonIndex);

                    _buttonGroups[groupIndex] = _buttonGroups[groupIndex]
                        .copyWith(buttons: updatedButtons);

                    _notifyGroupsChanged();
                  });
                },
                child: const Text('DELETE'),
              ),
            ],
          ),
    );
  }

  void _notifyGroupsChanged() {
    widget.onGroupsUpdated(_buttonGroups);
  }
}
