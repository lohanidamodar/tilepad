import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/design.dart';
import '../models/button.dart' as models;

/// Dialog for creating and editing pages.
///
/// A page now carries a name and a grid [models.Page.columns] width; tiles are
/// composed on the page itself, so this dialog only edits those two properties.
class PageEditorDialog extends StatefulWidget {
  /// The page to edit, null if creating a new page
  final models.Page? page;

  /// Creates a new page editor dialog
  const PageEditorDialog({super.key, this.page});

  @override
  State<PageEditorDialog> createState() => _PageEditorDialogState();
}

class _PageEditorDialogState extends State<PageEditorDialog> {
  /// Allowed grid widths a page can be laid out on.
  static const _columnOptions = [2, 3, 4, 5, 6];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _columns = 4;

  @override
  void initState() {
    super.initState();

    // Initialize form with existing page data if editing
    if (widget.page != null) {
      _nameController.text = widget.page!.name;
      _columns = widget.page!.columns;
    }
    // Keep the stored value selectable even if it falls outside the presets.
    if (!_columnOptions.contains(_columns)) {
      _columns = _columns.clamp(_columnOptions.first, _columnOptions.last);
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
        name: _nameController.text.trim(),
        order: widget.page?.order ?? 0,
        columns: _columns,
        tiles: widget.page?.tiles ?? [],
      );

      Navigator.of(context).pop(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: Container(
        padding: EdgeInsets.all(t.space.lg),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.page == null ? 'Create Page' : 'Edit Page',
                style: textTheme.headlineSmall,
              ),
              SizedBox(height: t.space.lg),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: const InputDecoration(
                  labelText: 'Page Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter a name for this page',
                ),
                onFieldSubmitted: (_) => _savePage(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a page name';
                  }
                  return null;
                },
              ),
              SizedBox(height: t.space.xl),
              Text(
                'Grid columns',
                style: textTheme.titleSmall?.copyWith(
                  color: t.color.textSecondary,
                ),
              ),
              SizedBox(height: t.space.xs),
              Text(
                'How many tiles wide this page lays out on the client.',
                style: textTheme.labelMedium?.copyWith(
                  color: t.color.textMuted,
                ),
              ),
              SizedBox(height: t.space.sm),
              SegmentedButton<int>(
                segments: [
                  for (final c in _columnOptions)
                    ButtonSegment<int>(value: c, label: Text('$c')),
                ],
                selected: {_columns},
                showSelectedIcon: false,
                onSelectionChanged: (sel) =>
                    setState(() => _columns = sel.first),
              ),
              SizedBox(height: t.space.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: t.space.lg),
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
