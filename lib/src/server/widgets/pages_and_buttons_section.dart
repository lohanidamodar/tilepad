import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../design/design.dart';
import '../../models/button.dart' as models;
import '../../utils/macro_icons.dart';

/// The page composer: understated page tabs on top, then the selected page's
/// tiles laid out on a spanning [StaggeredGrid]. Each tile is a colored chip
/// (the library button's icon/name/color) that can be tapped to edit, resized
/// through preset spans, moved, or removed. A "+ Add button" control opens the
/// library picker, and "Manage Buttons" opens the library manager.
class PagesAndButtonsSection extends StatelessWidget {
  final List<models.Page> pages;
  final models.Page? selectedPage;

  // Page management.
  final ValueChanged<models.Page?> onPageSelected;
  final VoidCallback onAddPage;
  final ValueChanged<models.Page> onEditPage;
  final ValueChanged<String> onDeletePage;
  final ValueChanged<int> onColumnsChanged;

  // Tile (placement) management on the selected page.
  final VoidCallback onAddTile;
  final ValueChanged<models.Tile> onEditTile;
  final ValueChanged<models.Tile> onRemoveTile;

  /// Resize a tile to a new (colSpan, rowSpan).
  final void Function(models.Tile tile, int colSpan, int rowSpan) onResizeTile;

  /// Reorder a tile within the page (old flow index -> new flow index).
  final void Function(int oldIndex, int newIndex) onReorderTile;

  /// Opens the library manager (edit/delete reusable buttons).
  final VoidCallback onManageButtons;

  const PagesAndButtonsSection({
    super.key,
    required this.pages,
    required this.selectedPage,
    required this.onPageSelected,
    required this.onAddPage,
    required this.onEditPage,
    required this.onDeletePage,
    required this.onColumnsChanged,
    required this.onAddTile,
    required this.onEditTile,
    required this.onRemoveTile,
    required this.onResizeTile,
    required this.onReorderTile,
    required this.onManageButtons,
  });

  /// Preset span presets a tile cycles through / can be picked from.
  static const _spanPresets = <_Span>[
    _Span(1, 1),
    _Span(2, 1),
    _Span(1, 2),
    _Span(2, 2),
  ];

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
            _buildComposerHeader(context, t),
            SizedBox(height: t.space.md),
            _buildGrid(context, t),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header (pages count + page actions + manage library)
  // ---------------------------------------------------------------------------

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
        TextButton.icon(
          onPressed: onManageButtons,
          icon: Icon(Icons.grid_view_outlined, size: t.icon.md),
          label: const Text('Manage Buttons'),
        ),
        SizedBox(width: t.space.xs),
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
        separatorBuilder: (_, _) => SizedBox(width: t.space.lg),
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
                    '${page.tiles.length}',
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

  // ---------------------------------------------------------------------------
  // Composer header (tile count, columns control, add button)
  // ---------------------------------------------------------------------------

  Widget _buildComposerHeader(BuildContext context, AppTokens t) {
    final textTheme = Theme.of(context).textTheme;
    final page = selectedPage;

    return Row(
      children: [
        Text(
          page != null ? '${page.name} Layout' : 'Layout',
          style: textTheme.titleSmall?.copyWith(color: t.color.textSecondary),
        ),
        if (page != null) ...[
          SizedBox(width: t.space.sm),
          Text(
            '${page.tiles.length}',
            style: textTheme.labelMedium?.copyWith(color: t.color.textMuted),
          ),
        ],
        const Spacer(),
        if (page != null) ...[
          _ColumnsControl(
            columns: page.columns,
            onChanged: onColumnsChanged,
          ),
          SizedBox(width: t.space.sm),
        ],
        TextButton.icon(
          onPressed: page != null ? onAddTile : null,
          icon: Icon(Icons.add, size: t.icon.md),
          label: const Text('Add button'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Grid
  // ---------------------------------------------------------------------------

  Widget _buildGrid(BuildContext context, AppTokens t) {
    final page = selectedPage;
    if (page == null || page.tiles.isEmpty) {
      return _buildEmptyState(context, t);
    }

    final columns = page.columns.clamp(1, 12);
    final tiles = page.tiles;

    return StaggeredGrid.count(
      crossAxisCount: columns,
      mainAxisSpacing: t.space.sm,
      crossAxisSpacing: t.space.sm,
      children: [
        for (var i = 0; i < tiles.length; i++)
          StaggeredGridTile.count(
            crossAxisCellCount: tiles[i].colSpan.clamp(1, columns),
            mainAxisCellCount: tiles[i].rowSpan.clamp(1, 6).toDouble(),
            child: _TileChip(
              tile: tiles[i],
              index: i,
              tileCount: tiles.length,
              columns: columns,
              spanPresets: _spanPresets,
              onEdit: () => onEditTile(tiles[i]),
              onRemove: () => onRemoveTile(tiles[i]),
              onResize: (c, r) => onResizeTile(tiles[i], c, r),
              onMove: (newIndex) => onReorderTile(i, newIndex),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AppTokens t) {
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
                  : Icons.add_to_queue_outlined,
              size: t.icon.xl,
              color: t.color.textMuted,
            ),
            SizedBox(height: t.space.md),
            Text(
              selectedPage == null
                  ? 'No page selected'
                  : 'No tiles on this page yet',
              style: textTheme.bodyMedium?.copyWith(color: t.color.textMuted),
              textAlign: TextAlign.center,
            ),
            if (selectedPage != null) ...[
              SizedBox(height: t.space.md),
              TextButton.icon(
                onPressed: onAddTile,
                icon: Icon(Icons.add, size: t.icon.md),
                label: const Text('Add button'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A simple immutable cell-span pair.
class _Span {
  final int col;
  final int row;
  const _Span(this.col, this.row);
}

/// Compact stepper to change the page grid column count (2..6).
class _ColumnsControl extends StatelessWidget {
  final int columns;
  final ValueChanged<int> onChanged;
  const _ColumnsControl({required this.columns, required this.onChanged});

  static const _min = 2;
  static const _max = 6;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
      decoration: BoxDecoration(
        color: t.color.surfaceSubtle,
        borderRadius: t.radius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xs),
            child: Text(
              'Cols',
              style: textTheme.labelMedium?.copyWith(color: t.color.textMuted),
            ),
          ),
          IconButton(
            onPressed:
                columns > _min ? () => onChanged(columns - 1) : null,
            icon: Icon(Icons.remove, size: t.icon.sm),
            tooltip: 'Fewer columns',
            visualDensity: VisualDensity.compact,
            color: t.color.textSecondary,
            padding: EdgeInsets.all(t.space.xxs),
            constraints: const BoxConstraints(),
          ),
          SizedBox(
            width: t.icon.lg,
            child: Text(
              '$columns',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ),
          IconButton(
            onPressed:
                columns < _max ? () => onChanged(columns + 1) : null,
            icon: Icon(Icons.add, size: t.icon.sm),
            tooltip: 'More columns',
            visualDensity: VisualDensity.compact,
            color: t.color.textSecondary,
            padding: EdgeInsets.all(t.space.xxs),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Possible actions surfaced in a tile's overflow menu.
enum _TileMenuAction { edit, sizeStart, moveLeft, moveRight, remove }

/// A single tile chip on the composer grid: the library button's color/icon/
/// name with an overflow menu for size/move/remove and tap-to-edit.
class _TileChip extends StatelessWidget {
  final models.Tile tile;
  final int index;
  final int tileCount;
  final int columns;
  final List<_Span> spanPresets;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final void Function(int colSpan, int rowSpan) onResize;
  final ValueChanged<int> onMove;

  const _TileChip({
    required this.tile,
    required this.index,
    required this.tileCount,
    required this.columns,
    required this.spanPresets,
    required this.onEdit,
    required this.onRemove,
    required this.onResize,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final color = _hexToColor(tile.button.color);
    final canMoveLeft = index > 0;
    final canMoveRight = index < tileCount - 1;

    return Material(
      color: color,
      borderRadius: t.radius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: EdgeInsets.all(t.space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    MacroIcons.resolve(tile.button.iconName),
                    size: t.icon.lg,
                    color: Colors.white,
                  ),
                  const Spacer(),
                  _TileMenu(
                    tile: tile,
                    columns: columns,
                    spanPresets: spanPresets,
                    canMoveLeft: canMoveLeft,
                    canMoveRight: canMoveRight,
                    onEdit: onEdit,
                    onRemove: onRemove,
                    onResize: onResize,
                    onMove: onMove,
                    index: index,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                tile.button.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: t.typeScale.wSemibold,
                ),
              ),
              SizedBox(height: t.space.xxs),
              Text(
                '${tile.colSpan}x${tile.rowSpan}',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overflow menu for a tile: size presets, move left/right, edit, remove.
class _TileMenu extends StatelessWidget {
  final models.Tile tile;
  final int index;
  final int columns;
  final List<_Span> spanPresets;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final void Function(int colSpan, int rowSpan) onResize;
  final ValueChanged<int> onMove;

  const _TileMenu({
    required this.tile,
    required this.index,
    required this.columns,
    required this.spanPresets,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onEdit,
    required this.onRemove,
    required this.onResize,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return PopupMenuButton<_TileMenuAction>(
      tooltip: 'Tile options',
      icon: Icon(Icons.more_vert, size: t.icon.md, color: Colors.white),
      padding: EdgeInsets.zero,
      splashRadius: t.icon.lg,
      onSelected: (action) {
        switch (action) {
          case _TileMenuAction.edit:
            onEdit();
            break;
          case _TileMenuAction.moveLeft:
            onMove(index - 1);
            break;
          case _TileMenuAction.moveRight:
            onMove(index + 1);
            break;
          case _TileMenuAction.remove:
            onRemove();
            break;
          case _TileMenuAction.sizeStart:
            // Size entries are handled via their dedicated values below.
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_TileMenuAction>(
          value: _TileMenuAction.edit,
          child: _menuRow(context, Icons.edit_outlined, 'Edit button'),
        ),
        const PopupMenuDivider(),
        // Size presets are rendered as a header + a row of choices below; to
        // keep them within the typed menu we expose them as enabled rows that
        // call onResize directly via a nested submenu-style list.
        for (final span in spanPresets)
          PopupMenuItem<_TileMenuAction>(
            // Reuse sizeStart as a no-op selected value; the tap closure does
            // the real work so each preset can carry its own dimensions.
            value: _TileMenuAction.sizeStart,
            onTap: () => onResize(span.col.clamp(1, columns), span.row),
            child: _menuRow(
              context,
              _spanIcon(span),
              'Size ${span.col}x${span.row}',
              selected: tile.colSpan == span.col && tile.rowSpan == span.row,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_TileMenuAction>(
          value: _TileMenuAction.moveLeft,
          enabled: canMoveLeft,
          child: _menuRow(context, Icons.arrow_back, 'Move earlier'),
        ),
        PopupMenuItem<_TileMenuAction>(
          value: _TileMenuAction.moveRight,
          enabled: canMoveRight,
          child: _menuRow(context, Icons.arrow_forward, 'Move later'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_TileMenuAction>(
          value: _TileMenuAction.remove,
          child: _menuRow(
            context,
            Icons.delete_outline,
            'Remove from page',
            danger: true,
          ),
        ),
      ],
    );
  }

  IconData _spanIcon(_Span span) {
    if (span.col == 1 && span.row == 1) return Icons.crop_square;
    if (span.col == 2 && span.row == 1) return Icons.crop_16_9;
    if (span.col == 1 && span.row == 2) return Icons.crop_portrait;
    return Icons.crop_din;
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String label, {
    bool selected = false,
    bool danger = false,
  }) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final color = danger ? t.color.danger : t.color.textPrimary;
    return Row(
      children: [
        Icon(icon, size: t.icon.md, color: color),
        SizedBox(width: t.space.md),
        Text(label, style: textTheme.bodyMedium?.copyWith(color: color)),
        if (selected) ...[
          const Spacer(),
          Icon(Icons.check, size: t.icon.sm, color: t.color.accent),
        ],
      ],
    );
  }
}

/// Converts a hex string to a Color, falling back to the default color
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
