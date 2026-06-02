// filepath: g:\dev\projects\macro-deck\lib\src\server\page_editor_dialog.dart
import 'package:flutter/material.dart';
import '../design/design.dart';
import '../models/button.dart' as models;

/// Dialog for creating and editing pages of buttons
class PageEditorDialog extends StatefulWidget {
  /// The page to edit, null if creating a new page
  final models.Page? page;

  /// Creates a new page editor dialog
  const PageEditorDialog({super.key, this.page});

  @override
  State<PageEditorDialog> createState() => _PageEditorDialogState();
}

class _PageEditorDialogState extends State<PageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize form with existing page data if editing
    if (widget.page != null) {
      _nameController.text = widget.page!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Saves the page and returns it
  void _savePage() {
    if (_formKey.currentState!.validate()) {
      final page = models.Page(
        id: widget.page?.id,
        name: _nameController.text,
        order: widget.page?.order ?? 0,
        buttons: widget.page?.buttons ?? [],
      );

      Navigator.of(context).pop(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(context.tokens.space.lg),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.page == null ? 'Create Page' : 'Edit Page',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: context.tokens.space.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Page Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter a name for this page',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a page name';
                  }
                  return null;
                },
              ),
              SizedBox(height: context.tokens.space.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: context.tokens.space.lg),
                  ElevatedButton(
                    onPressed: _savePage,
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
