import 'package:flutter/material.dart';
import '../../models/button.dart' as models;
import '../../utils/macro_icons.dart';

/// A widget that displays the pages and buttons section
class PagesAndButtonsSection extends StatelessWidget {
  final List<models.Page> pages;
  final models.Page? selectedPage;
  final Function(models.Page?) onPageSelected;
  final VoidCallback onAddPage;
  final Function(models.Page) onEditPage;
  final Function(String) onDeletePage;
  final VoidCallback onAddButton;
  final Function(models.Button) onEditButton;
  final Function(String) onDeleteButton;
  final Function(int, int) onReorderButtons;

  const PagesAndButtonsSection({
    super.key,
    required this.pages,
    required this.selectedPage,
    required this.onPageSelected,
    required this.onAddPage,
    required this.onEditPage,
    required this.onDeletePage,
    required this.onAddButton,
    required this.onEditButton,
    required this.onDeleteButton,
    required this.onReorderButtons,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colorScheme),
            if (pages.isNotEmpty) _buildPageTabs(colorScheme),
            _buildButtonsHeader(colorScheme),
            _buildButtonsList(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.tertiaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.dashboard_rounded,
                  color: colorScheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Button Pages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${pages.length}',
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onAddPage,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Page'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.tertiary.withValues(alpha: 0.3),
                  foregroundColor: colorScheme.onTertiaryContainer,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
              ),
              if (selectedPage != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onEditPage(selectedPage!),
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Page',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.tertiary.withValues(
                      alpha: 0.2,
                    ),
                    foregroundColor: colorScheme.onTertiaryContainer,
                  ),
                ),
                IconButton(
                  onPressed: () => onDeletePage(selectedPage!.id),
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Page',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.error.withValues(alpha: 0.2),
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageTabs(ColorScheme colorScheme) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          final isSelected = selectedPage?.id == page.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color:
                  isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPageSelected(page),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      if (isSelected) const SizedBox(width: 8),
                      Text(
                        page.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color:
                              isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.3)
                                  : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${page.buttons.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonsHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                selectedPage != null
                    ? '${selectedPage!.name} Buttons'
                    : 'Buttons',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (selectedPage != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedPage!.buttons.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          FilledButton.icon(
            onPressed: selectedPage != null ? onAddButton : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Button'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsList(ColorScheme colorScheme) {
    if (selectedPage == null || selectedPage!.buttons.isEmpty) {
      return _buildEmptyButtonsState(colorScheme);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      // Use our own drag handle instead of the platform default so desktop
      // doesn't render a second, redundant handle.
      buildDefaultDragHandles: false,
      // This list lives inside the outer scrolling ListView of ServerScreen,
      // so defer scrolling to the parent to avoid nested-scroll conflicts.
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      onReorder: onReorderButtons,
      itemCount: selectedPage!.buttons.length,
      itemBuilder: (context, index) {
        final button = selectedPage!.buttons[index];
        return _buildButtonCard(button, index, colorScheme);
      },
    );
  }

  Widget _buildEmptyButtonsState(ColorScheme colorScheme) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surface.withValues(alpha: 0.5),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedPage == null
                  ? Icons.dashboard_customize
                  : Icons.touch_app,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              selectedPage == null
                  ? 'No page selected'
                  : 'No buttons on this page yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              selectedPage == null
                  ? 'Please create or select a page first'
                  : 'Click "Add Button" to create your first button',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: selectedPage == null ? onAddPage : onAddButton,
              icon: Icon(selectedPage == null ? Icons.add_circle : Icons.add),
              label: Text(selectedPage == null ? 'Create Page' : 'Add Button'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonCard(
    models.Button button,
    int index,
    ColorScheme colorScheme,
  ) {
    return Card(
      key: ValueKey(button.id),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onEditButton(button),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _hexToColor(button.color),
                child: Icon(_getIconData(button.iconName), color: Colors.white),
              ),
              title: Text(
                button.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                button.actions.isNotEmpty
                    ? _getActionDescription(button.actions.first)
                    : 'No actions',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            onTap: () => onEditButton(button),
                            child: const Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            onTap: () => onDeleteButton(button.id),
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: colorScheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Converts a hex string to a Color, falling back to the default colour
  /// when the stored value is malformed.
  Color _hexToColor(String hexString) {
    var hexColor = hexString.replaceAll('#', '').trim();
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    final value = int.tryParse(hexColor, radix: 16);
    if (value == null || hexColor.length != 8) {
      return const Color(0xFF4285F4);
    }
    return Color(value);
  }

  /// Resolves a stored icon identifier to its Phosphor [IconData].
  IconData _getIconData(String iconName) => MacroIcons.resolve(iconName);

  /// Gets a description of a button action
  String _getActionDescription(models.ButtonAction action) {
    switch (action.type) {
      case models.ActionType.command:
        return 'Command: ${action.command}';
      case models.ActionType.commandPreset:
        return 'Preset: ${action.command}';
      case models.ActionType.keystroke:
        final modifierText =
            action.modifiers.isNotEmpty
                ? '${action.modifiers.map((m) => m.toUpperCase()).join('+')}+'
                : '';
        return 'Keystroke: $modifierText${action.key.toUpperCase()}';
    }
  }
}
