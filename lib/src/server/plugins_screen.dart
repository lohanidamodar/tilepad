import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'plugins/plugin_manifest.dart';
import 'plugins/plugin_registry.dart';
import 'server.dart';

/// Lists installed plugins and lets the user enable/disable, configure and
/// remove them, plus open the plugins folder to drop new ones in.
class PluginsScreen extends StatefulWidget {
  final MarcoServer server;
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
      builder: (context) => _PluginSettingsDialog(plugin: plugin),
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
          const SizedBox(width: 8),
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
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: plugins.isEmpty
                      ? _buildEmptyState(context)
                      : ListView(
                          padding: const EdgeInsets.all(16),
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
    return Positioned.fill(
      child: Container(
        color: colorScheme.primary.withValues(alpha: 0.12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined,
                    size: 40, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Drop a plugin folder or .zip to install',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_outlined,
                size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No plugins installed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Drag a plugin folder or .zip here, or use the + button to add '
              'one. It is copied into the plugins folder and stays disabled '
              'until you turn it on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
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
    final manifest = plugin.manifest;
    final connected = widget.server.isPluginConnected(manifest.id);
    final hasSettings = manifest.settings.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.extension,
                  color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          manifest.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(plugin.enabled, connected, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${manifest.version} · ${manifest.author}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (manifest.actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${manifest.actions.length} action(s)'
                        '${manifest.states.isNotEmpty ? ' · ${manifest.states.length} live state(s)' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasSettings)
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: 'Settings',
                onPressed: _busy ? null : () => _editSettings(plugin),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
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
    late final Color color;
    late final String label;
    if (!enabled) {
      color = colorScheme.outline;
      label = 'Disabled';
    } else if (connected) {
      color = Colors.green;
      label = 'Connected';
    } else {
      color = Colors.orange;
      label = 'Starting…';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildErrors(List<String> errors, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Some plugins could not be loaded:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer)),
            const SizedBox(height: 4),
            for (final e in errors)
              Text('• $e',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onErrorContainer)),
          ],
        ),
      ),
    );
  }
}

/// A dialog that renders a plugin's settings fields natively from its manifest.
class _PluginSettingsDialog extends StatefulWidget {
  final InstalledPlugin plugin;
  const _PluginSettingsDialog({required this.plugin});

  @override
  State<_PluginSettingsDialog> createState() => _PluginSettingsDialogState();
}

class _PluginSettingsDialogState extends State<_PluginSettingsDialog> {
  late final Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = {
      for (final field in widget.plugin.manifest.settings)
        field.key: widget.plugin.settings[field.key] ?? field.defaultValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.plugin.manifest.settings;
    return AlertDialog(
      title: Text('${widget.plugin.manifest.name} settings'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: PluginFieldInput(
                    field: field,
                    value: _values[field.key],
                    onChanged: (v) => setState(() => _values[field.key] = v),
                  ),
                ),
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
        return TextFormField(
          initialValue: effectiveValue?.toString() ?? '',
          obscureText: true,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
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
