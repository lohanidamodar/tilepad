import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../models/button.dart' as models;
import '../../utils/macro_icons.dart';

/// A flat, minimal pages-and-buttons block: a quiet header with page actions,
/// understated page tabs, and a clean hairline-separated list of buttons.
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

    return Card(
      child: Padding(
        padding: EdgeInsets.all(t.space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, t),
            if (pages.isNotEmpty) ...[
              SizedBox(height: t.space.lg),
              _buildPageTabs(context, t),
            ],
            SizedBox(height: t.space.lg),
            Divider(height: t.border.hairline, color: t.color.border),
            SizedBox(height: t.space.lg),
            _buildButtonsHeader(context, t),
            _buildButtonsList(context, t),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text('Pages', style: textTheme.titleMedium),
        SizedBox(width: t.space.sm),
        Text(
          '${pages.length}',
          style: textTheme.labelMedium?.copyWith(color: t.color.textMuted),
        ),
        const Spacer(),
        if (selectedPage != null) ...[
          IconButton(
            onPressed: () => onEditPage(selectedPage!),
            icon: Icon(Icons.edit_outlined, size: t.icon.lg),
            tooltip: 'Edit Page',
            color: t.color.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => onDeletePage(selectedPage!.id),
            icon: Icon(Icons.delete_outline, size: t.icon.lg),
            tooltip: 'Delete Page',
            color: t.color.danger,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(width: t.space.xs),
        ],
        TextButton.icon(
          onPressed: onAddPage,
          icon: Icon(Icons.add, size: t.icon.md),
          label: const Text('New Page'),
        ),
      ],
    );
  }

  Widget _buildPageTabs(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: t.space.xxl + t.space.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pages.length,
        separatorBuilder: (_, __) => SizedBox(width: t.space.lg),
        itemBuilder: (context, index) {
          final page = pages[index];
          final isSelected = selectedPage?.id == page.id;

          return InkWell(
            onTap: () => onPageSelected(page),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? t.color.accent : Colors.transparent,
                    width: t.border.strong,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    page.name,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? t.color.textPrimary
                          : t.color.textMuted,
                      fontWeight: isSelected
                          ? t.typeScale.wSemibold
                          : t.typeScale.wRegular,
                    ),
                  ),
                  SizedBox(width: t.space.xs + t.space.xxs),
                  Text(
                    '${page.buttons.length}',
                    style: textTheme.labelSmall?.copyWith(
                      color: t.color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonsHeader(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          selectedPage != null ? '${selectedPage!.name} Buttons' : 'Buttons',
          style: textTheme.titleSmall?.copyWith(color: t.color.textSecondary),
        ),
        if (selectedPage != null) ...[
          SizedBox(width: t.space.sm),
          Text(
            '${selectedPage!.buttons.length}',
            style: textTheme.labelMedium?.copyWith(color: t.color.textMuted),
          ),
        ],
        const Spacer(),
        TextButton.icon(
          onPressed: selectedPage != null ? onAddButton : null,
          icon: Icon(Icons.add, size: t.icon.md),
          label: const Text('Add Button'),
        ),
      ],
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
      padding: EdgeInsets.only(top: t.space.xs),
      onReorderItem: onReorderButtons,
      itemCount: selectedPage!.buttons.length,
      itemBuilder: (context, index) {
        final button = selectedPage!.buttons[index];
        return _buildButtonRow(context, t, button, index);
      },
    );
  }

  Widget _buildEmptyButtonsState(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selectedPage == null
                  ? Icons.dashboard_customize_outlined
                  : Icons.touch_app_outlined,
              size: t.icon.xl,
              color: t.color.textMuted,
            ),
            SizedBox(height: t.space.md),
            Text(
              selectedPage == null
                  ? 'No page selected'
                  : 'No buttons on this page yet',
              style: textTheme.bodyMedium?.copyWith(color: t.color.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(
    BuildContext context,
    AppTokens t,
    models.Button button,
    int index,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: ValueKey(button.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          Divider(height: t.border.hairline, color: t.color.border),
        InkWell(
          onTap: () => onEditButton(button),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: t.space.md),
            child: Row(
              children: [
                // Thin leading bar carrying the per-button user color, kept
                // subtle so it reads as a marker rather than a filled chip.
                Container(
                  width: t.border.strong,
                  height: t.icon.xl,
                  color: _hexToColor(button.color),
                ),
                SizedBox(width: t.space.md),
                Icon(
                  _getIconData(button.iconName),
                  size: t.icon.lg,
                  color: t.color.textSecondary,
                ),
                SizedBox(width: t.space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        button.name,
                        style: textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: t.space.xxs),
                      Text(
                        button.actions.isNotEmpty
                            ? _getActionDescription(button.actions.first)
                            : 'No actions',
                        style: textTheme.labelMedium?.copyWith(
                          color: t.color.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.space.sm),
                IconButton(
                  onPressed: () => onEditButton(button),
                  icon: Icon(Icons.edit_outlined, size: t.icon.md),
                  tooltip: 'Edit',
                  color: t.color.textMuted,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => onDeleteButton(button.id),
                  icon: Icon(Icons.delete_outline, size: t.icon.md),
                  tooltip: 'Delete',
                  color: t.color.danger,
                  visualDensity: VisualDensity.compact,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.space.xs),
                    child: Icon(
                      Icons.drag_indicator,
                      size: t.icon.md,
                      color: t.color.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
