import 'package:flutter/material.dart';

import 'macro_icons.dart';

/// A dialog that displays a searchable grid of Phosphor icons.
class IconPickerDialog extends StatefulWidget {
  /// Creates a new icon picker dialog.
  const IconPickerDialog({super.key});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final List<MapEntry<String, IconData>> _allIcons =
      MacroIcons.picker.entries.toList();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, IconData>> get _filteredIcons {
    if (_searchQuery.isEmpty) return _allIcons;
    return _allIcons
        .where((entry) => entry.key.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an Icon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Search icons',
                hintText: 'e.g. play, power, volume, folder',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isEmpty
                        ? null
                        : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _searchController.clear,
                        ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _filteredIcons.isEmpty
                      ? Center(
                        child: Text(
                          'No icons found',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 84,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _filteredIcons.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredIcons[index];
                          return _IconTile(
                            label: entry.key,
                            icon: entry.value,
                            onTap: () => Navigator.of(context).pop(entry.value),
                          );
                        },
                      ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: colorScheme.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
