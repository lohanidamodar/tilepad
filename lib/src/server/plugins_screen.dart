import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../design/design.dart';
import 'plugins/plugin_manifest.dart';
import 'plugins/plugin_registry.dart';
import 'server.dart';

/// Lists installed plugins and lets the user enable/disable, configure and
/// remove them, plus open the plugins folder to drop new ones in.
class PluginsScreen extends StatefulWidget {
  final TilepadServer server;
  const PluginsScreen({super.key, required this.server});

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  bool _busy = false;
  bool _dragging = false;
  StreamSubscription<String>? _connSub;

  @override
  void initState() {
    super.initState();
    // Refresh the connected/disabled chips when a plugin connects or drops,
    // so enabling a plugin flips "Starting…" to "Connected" on its own.
    _connSub = widget.server.pluginConnectionChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Installs a plugin from a dropped/picked path (folder or .zip) and reports
  /// the outcome. Validation (must contain a manifest) happens in the server.
  Future<void> _install(String path) async {
    await _run(() async {
      try {
        final id = await widget.server.installPluginFromPath(path);
        await widget.server.rescanPlugins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Installed "$id" (disabled)')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not install plugin: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    });
  }

  Future<void> _addFromFolder() async {
    final path = await getDirectoryPath();
    if (path != null) await _install(path);
  }

  Future<void> _addFromZip() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Plugin package', extensions: ['zip']),
      ],
    );
    if (file != null) await _install(file.path);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    final paths = details.files.map((f) => f.path).toList();
    if (paths.isEmpty) return;
    // Install the whole batch under one busy cycle and report a single summary.
    await _run(() async {
      var ok = 0;
      final failures = <String>[];
      for (final path in paths) {
        try {
          final id = await widget.server.installPluginFromPath(path);
          ok++;
          await widget.server.rescanPlugins();
          if (id.isEmpty) failures.add(path);
        } catch (e) {
          failures.add('$path: $e');
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (failures.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('Installed $ok plugin(s) (disabled)')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Installed $ok, failed ${failures.length}: ${failures.first}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
  }

  Future<void> _toggle(InstalledPlugin plugin, bool enable) => _run(() async {
        if (enable) {
          await widget.server.enablePlugin(plugin.manifest.id);
        } else {
          await widget.server.disablePlugin(plugin.manifest.id);
        }
      });

  Future<void> _remove(InstalledPlugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${plugin.manifest.name}?'),
        content: const Text(
          'This deletes the plugin and its files from disk. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => widget.server.removePlugin(plugin.manifest.id));
    }
  }

  Future<void> _editSettings(InstalledPlugin plugin) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _PluginSettingsDialog(plugin: plugin, server: widget.server),
    );
    if (values != null) {
      await _run(
        () => widget.server.updatePluginSettings(plugin.manifest.id, values),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final plugins = widget.server.plugins;
    final errors = widget.server.pluginErrors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugins'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Add plugin',
            icon: const Icon(Icons.add),
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'folder') _addFromFolder();
              if (value == 'zip') _addFromZip();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'folder',
                child: ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('From folder…'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'zip',
                child: ListTile(
                  leading: Icon(Icons.folder_zip_outlined),
                  title: Text('From .zip…'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Open plugins folder',
            onPressed: _busy ? null : widget.server.openPluginsFolder,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan',
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await widget.server.rescanPlugins();
                    }),
          ),
          SizedBox(width: tokens.space.sm),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          _onDrop(details);
        },
        child: Stack(
          children: [
            Column(
              children: [
                if (_busy)
                  LinearProgressIndicator(minHeight: tokens.border.focus),
                Expanded(
                  child: plugins.isEmpty
                      ? _buildEmptyState(context)
                      : ListView(
                          padding: EdgeInsets.all(tokens.space.lg),
                          children: [
                            for (final plugin in plugins)
                              _buildPluginCard(plugin),
                            if (errors.isNotEmpty)
                              _buildErrors(errors, colorScheme),
                          ],
                        ),
                ),
              ],
            ),
            if (_dragging) _buildDropOverlay(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDropOverlay(ColorScheme colorScheme) {
    final tokens = context.tokens;
    return Positioned.fill(
      child: Container(
        color: tokens.color.accentSubtle,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space.xxl,
              vertical: tokens.space.xl,
            ),
            decoration: BoxDecoration(
              color: tokens.color.surface,
              borderRadius: tokens.radius.brLg,
              border: Border.all(
                color: tokens.color.accent,
                width: tokens.border.focus,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined,
                    size: tokens.space.huge, color: tokens.color.accent),
                SizedBox(height: tokens.space.sm),
                Text(
                  'Drop a plugin folder or .zip to install',
                  style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: tokens.color.accent,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_outlined,
                size: tokens.space.huge, color: tokens.color.textSecondary),
            SizedBox(height: tokens.space.lg),
            Text('No plugins installed',
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: tokens.space.sm),
            Text(
              'Drag a plugin folder or .zip here, or use the + button to add '
              'one. It is copied into the plugins folder and stays disabled '
              'until you turn it on.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.color.textSecondary),
            ),
            SizedBox(height: tokens.space.lg),
            Wrap(
              spacing: tokens.space.md,
              children: [
                FilledButton.icon(
                  onPressed: _addFromFolder,
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('Add from folder'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.server.openPluginsFolder,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open plugins folder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginCard(InstalledPlugin plugin) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final manifest = plugin.manifest;
    final connected = widget.server.isPluginConnected(manifest.id);
    final hasSettings = manifest.settings.isNotEmpty;

    return Card(
      margin: EdgeInsets.only(bottom: tokens.space.md),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.space.lg,
          tokens.space.md,
          tokens.space.sm,
          tokens.space.md,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(tokens.space.sm),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: tokens.radius.brSm,
              ),
              child: Icon(Icons.extension,
                  color: colorScheme.onPrimaryContainer),
            ),
            SizedBox(width: tokens.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          manifest.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: tokens.space.sm),
                      _statusChip(plugin.enabled, connected, colorScheme),
                    ],
                  ),
                  SizedBox(height: tokens.space.xxs),
                  Text(
                    'v${manifest.version} · ${manifest.author}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (manifest.actions.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: tokens.space.xs),
                      child: Text(
                        '${manifest.actions.length} action(s)'
                        '${manifest.states.isNotEmpty ? ' · ${manifest.states.length} live state(s)' : ''}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasSettings)
              IconButton(
                icon: Icon(Icons.settings_outlined, size: tokens.icon.lg),
                tooltip: 'Settings',
                onPressed: _busy ? null : () => _editSettings(plugin),
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: tokens.icon.lg),
              tooltip: 'Remove',
              onPressed: _busy ? null : () => _remove(plugin),
            ),
            Switch(
              value: plugin.enabled,
              onChanged:
                  _busy ? null : (value) => _toggle(plugin, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool enabled, bool connected, ColorScheme colorScheme) {
    final tokens = context.tokens;
    late final Color color;
    late final Color background;
    late final String label;
    if (!enabled) {
      color = tokens.color.textMuted;
      background = tokens.color.surfaceSubtle;
      label = 'Disabled';
    } else if (connected) {
      color = tokens.color.success;
      background = tokens.color.successSubtle;
      label = 'Connected';
    } else {
      color = tokens.color.warning;
      background = tokens.color.warningSubtle;
      label = 'Starting…';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space.sm,
        vertical: tokens.space.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.radius.brXl,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }

  Widget _buildErrors(List<String> errors, ColorScheme colorScheme) {
    final tokens = context.tokens;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: EdgeInsets.all(tokens.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Some plugins could not be loaded:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onErrorContainer,
                    )),
            SizedBox(height: tokens.space.xs),
            for (final e in errors)
              Text('• $e',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      )),
          ],
        ),
      ),
    );
  }
}

/// A dialog that renders a plugin's settings fields natively from its manifest.
class _PluginSettingsDialog extends StatefulWidget {
  final InstalledPlugin plugin;
  final TilepadServer server;
  const _PluginSettingsDialog({required this.plugin, required this.server});

  @override
  State<_PluginSettingsDialog> createState() => _PluginSettingsDialogState();
}

/// Action id a plugin can declare to expose a "Test Connection" button here.
const String _testConnectionActionId = 'test_connection';

class _PluginSettingsDialogState extends State<_PluginSettingsDialog> {
  late final Map<String, dynamic> _values;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  bool get _hasTest => widget.plugin.manifest.actions
      .any((a) => a.id == _testConnectionActionId);

  @override
  void initState() {
    super.initState();
    _values = {
      for (final field in widget.plugin.manifest.settings)
        field.key: widget.plugin.settings[field.key] ?? field.defaultValue,
    };
  }

  /// Applies the entered settings, then invokes the plugin's test action so the
  /// test runs against the values the user just typed.
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final id = widget.plugin.manifest.id;
    await widget.server.updatePluginSettings(id, _values);
    // Give the plugin a moment to reconnect with the new settings.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final result =
        await widget.server.invokePluginAction(id, _testConnectionActionId);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = result.success;
      _testMessage = result.success
          ? (result.output.isNotEmpty ? result.output : 'Connected')
          : (result.error.isNotEmpty ? result.error : 'Connection failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fields = widget.plugin.manifest.settings;
    return AlertDialog(
      title: Text('${widget.plugin.manifest.name} settings'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.space.xs),
                  child: PluginFieldInput(
                    field: field,
                    value: _values[field.key],
                    onChanged: (v) => setState(() => _values[field.key] = v),
                  ),
                ),
              if (_hasTest) ...[
                SizedBox(height: tokens.space.sm),
                OutlinedButton.icon(
                  onPressed: (_testing || !widget.plugin.enabled) ? null : _test,
                  icon: _testing
                      ? SizedBox(
                          width: tokens.icon.md,
                          height: tokens.icon.md,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_testing ? 'Testing…' : 'Test Connection'),
                ),
                if (!widget.plugin.enabled)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.space.xs),
                    child: Text(
                      'Enable the plugin first to test it.',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: tokens.color.textMuted),
                    ),
                  ),
                if (_testMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.space.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _testOk ? Icons.check_circle : Icons.error_outline,
                          size: tokens.icon.md,
                          color: _testOk ? tokens.color.success : tokens.color.danger,
                        ),
                        SizedBox(width: tokens.space.xs),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _testOk
                                      ? tokens.color.success
                                      : tokens.color.danger,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _values),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Renders a single plugin field (settings or action field) as a native input.
///
/// Shared by the settings dialog and the button action editor so plugin authors
/// get consistent native UI from their manifest with no web tech.
class PluginFieldInput extends StatelessWidget {
  final PluginField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  /// Options for a [PluginFieldType.select] resolved from a dynamic list.
  final List<PluginFieldOption> dynamicOptions;

  const PluginFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.dynamicOptions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Fall back to the field's declared default when no value is set, so the
    // widget renders correct defaults even if a caller doesn't pre-seed them.
    final effectiveValue = value ?? field.defaultValue;
    switch (field.type) {
      case PluginFieldType.bool:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: effectiveValue == true,
          onChanged: onChanged,
        );
      case PluginFieldType.select:
        final options =
            dynamicOptions.isNotEmpty ? dynamicOptions : field.options;
        return InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: options.any((o) => o.value == effectiveValue)
                  ? effectiveValue as String?
                  : null,
              hint: const Text('Select…'),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o.value, child: Text(o.label)),
              ],
              onChanged: onChanged,
            ),
          ),
        );
      case PluginFieldType.number:
        return TextFormField(
          initialValue: effectiveValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          // Never persist a raw string into a numeric field: empty -> null,
          // otherwise the parsed number (and keep null while half-typed).
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : num.tryParse(v)),
        );
      case PluginFieldType.password:
        return _PasswordField(
          label: field.label,
          initialValue: effectiveValue?.toString() ?? '',
          onChanged: onChanged,
        );
      case PluginFieldType.string:
        return TextFormField(
          initialValue: effectiveValue?.toString() ?? '',
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        );
    }
  }
}

/// A password field with a show/hide visibility toggle.
class _PasswordField extends StatefulWidget {
  final String label;
  final String initialValue;
  final ValueChanged<dynamic> onChanged;

  const _PasswordField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.initialValue,
      obscureText: _obscured,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(
            _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: context.tokens.icon.md,
          ),
          tooltip: _obscured ? 'Show' : 'Hide',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
