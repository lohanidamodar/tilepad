import 'package:flutter/material.dart';
import '../../design/design.dart';
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
    final t = context.tokens;

    return Container(
      margin: EdgeInsets.only(top: t.space.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, t),
            if (pages.isNotEmpty) _buildPageTabs(context, t),
            _buildButtonsHeader(context, t),
            _buildButtonsList(context, t),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTokens t) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.space.xl,
        vertical: t.space.lg,
      ),
      decoration: BoxDecoration(color: t.color.accentSubtle),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(t.space.sm),
                decoration: BoxDecoration(
                  color: t.color.accent.withValues(alpha: t.opacity.subtle),
                  borderRadius: t.radius.brSm,
                ),
                child: Icon(
                  Icons.dashboard_rounded,
                  color: t.color.accent,
                  size: t.icon.lg,
                ),
              ),
              SizedBox(width: t.space.md),
              Text(
                'Button Pages',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: t.color.textPrimary,
                    ),
              ),
              SizedBox(width: t.space.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.sm,
                  vertical: t.space.xs,
                ),
                decoration: BoxDecoration(
                  color: t.color.accent.withValues(alpha: t.opacity.subtle),
                  borderRadius: t.radius.brMd,
                ),
                child: Text(
                  '${pages.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: t.color.accent,
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
                  backgroundColor:
                      t.color.accent.withValues(alpha: t.opacity.subtle),
                  foregroundColor: t.color.accent,
                  padding: EdgeInsets.symmetric(
                    vertical: t.space.sm,
                    horizontal: t.space.md,
                  ),
                ),
              ),
              if (selectedPage != null) ...[
                SizedBox(width: t.space.sm),
                IconButton(
                  onPressed: () => onEditPage(selectedPage!),
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Page',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        t.color.accent.withValues(alpha: t.opacity.subtle),
                    foregroundColor: t.color.accent,
                  ),
                ),
                IconButton(
                  onPressed: () => onDeletePage(selectedPage!.id),
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Page',
                  style: IconButton.styleFrom(
                    backgroundColor: t.color.dangerSubtle,
                    foregroundColor: t.color.danger,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageTabs(BuildContext context, AppTokens t) {
    return Container(
      height: t.space.huge,
      margin: EdgeInsets.only(top: t.space.md, bottom: t.space.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.space.lg),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          final isSelected = selectedPage?.id == page.id;

          return Padding(
            padding: EdgeInsets.only(right: t.space.sm),
            child: Material(
              color: isSelected ? t.color.accentSubtle : t.color.surfaceSubtle,
              borderRadius: t.radius.brLg,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPageSelected(page),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.lg,
                    vertical: t.space.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.circle,
                          size: t.space.sm,
                          color: t.color.accent,
                        ),
                      if (isSelected) SizedBox(width: t.space.sm),
                      Text(
                        page.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected
                                  ? t.typeScale.wSemibold
                                  : t.typeScale.wRegular,
                              color: isSelected
                                  ? t.color.accent
                                  : t.color.textSecondary,
                            ),
                      ),
                      SizedBox(width: t.space.sm),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: t.space.xs + t.space.xxs,
                          vertical: t.space.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? t.color.accent
                                  .withValues(alpha: t.opacity.subtle)
                              : t.color.surfaceRaised,
                          borderRadius: t.radius.brSm,
                        ),
                        child: Text(
                          '${page.buttons.length}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: t.typeScale.wSemibold,
                                    color: isSelected
                                        ? t.color.accent
                                        : t.color.textSecondary,
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

  Widget _buildButtonsHeader(BuildContext context, AppTokens t) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.lg,
        vertical: t.space.md,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.color.border),
          bottom: BorderSide(color: t.color.border),
        ),
        color: t.color.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, color: t.color.accent, size: t.icon.lg),
              SizedBox(width: t.space.sm),
              Text(
                selectedPage != null
                    ? '${selectedPage!.name} Buttons'
                    : 'Buttons',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: t.color.textSecondary,
                    ),
              ),
              if (selectedPage != null) ...[
                SizedBox(width: t.space.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.sm,
                    vertical: t.space.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: t.color.accentSubtle,
                    borderRadius: t.radius.brMd,
                  ),
                  child: Text(
                    '${selectedPage!.buttons.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: t.typeScale.wSemibold,
                          color: t.color.accent,
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
              padding: EdgeInsets.symmetric(
                horizontal: t.space.md,
                vertical: t.space.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsList(BuildContext context, AppTokens t) {
    if (selectedPage == null || selectedPage!.buttons.isEmpty) {
      return _buildEmptyButtonsState(context, t);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      // Use our own drag handle instead of the platform default so desktop
      // doesn't render a second, redundant handle.
      buildDefaultDragHandles: false,
      // This list lives inside the outer scrolling ListView of ServerScreen,
      // so defer scrolling to the parent to avoid nested-scroll conflicts.
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        vertical: t.space.sm,
        horizontal: t.space.lg,
      ),
      onReorderItem: onReorderButtons,
      itemCount: selectedPage!.buttons.length,
      itemBuilder: (context, index) {
        final button = selectedPage!.buttons[index];
        return _buildButtonCard(context, t, button, index);
      },
    );
  }

  Widget _buildEmptyButtonsState(BuildContext context, AppTokens t) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: EdgeInsets.all(t.space.xxl),
        margin: EdgeInsets.all(t.space.lg),
        decoration: BoxDecoration(
          borderRadius: t.radius.brLg,
          color: t.color.surfaceSubtle,
          border: Border.all(color: t.color.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedPage == null
                  ? Icons.dashboard_customize
                  : Icons.touch_app,
              size: t.space.huge,
              color: t.color.textMuted,
            ),
            SizedBox(height: t.space.lg),
            Text(
              selectedPage == null
                  ? 'No page selected'
                  : 'No buttons on this page yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: t.color.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.space.sm),
            Text(
              selectedPage == null
                  ? 'Please create or select a page first'
                  : 'Click "Add Button" to create your first button',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: t.color.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.space.lg),
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
    BuildContext context,
    AppTokens t,
    models.Button button,
    int index,
  ) {
    return Card(
      key: ValueKey(button.id),
      margin: EdgeInsets.only(bottom: t.space.sm),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onEditButton(button),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _hexToColor(button.color),
                child: Icon(
                  _getIconData(button.iconName),
                  color: t.color.onAccent,
                ),
              ),
              title: Text(
                button.name,
                style: Theme.of(context).textTheme.titleSmall,
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
                      color: t.color.textSecondary,
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () => onEditButton(button),
                        child: Row(
                          children: [
                            const Icon(Icons.edit),
                            SizedBox(width: t.space.sm),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () => onDeleteButton(button.id),
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: t.color.danger),
                            SizedBox(width: t.space.sm),
                            Text(
                              'Delete',
                              style: TextStyle(color: t.color.danger),
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
      case models.ActionType.promptText:
        return 'Prompt for text';
      case models.ActionType.promptKeystroke:
        return 'Prompt for key combo';
      case models.ActionType.selectWindow:
        return 'Select a window to focus';
      case models.ActionType.plugin:
        return 'Plugin: ${action.pluginActionId}';
    }
  }
}
