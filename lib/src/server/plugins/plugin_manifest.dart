/// Typed models for a plugin's `manifest.json`, plus parsing/validation.
///
/// A manifest is the contract a plugin author provides so Tilepad can present
/// the plugin's actions, settings, live states and dynamic lists without the
/// plugin author writing any UI. See `docs/plugins/protocol.md`.
library;

/// Thrown when a `manifest.json` is missing required fields or contains
/// malformed values.
class PluginManifestException implements Exception {
  final String message;
  PluginManifestException(this.message);
  @override
  String toString() => 'PluginManifestException: $message';
}

/// The kind of a settings/action input field. Determines how the server editor
/// renders it natively.
enum PluginFieldType {
  string,
  password,
  number,
  bool,
  select;

  static PluginFieldType parse(String raw) {
    for (final v in PluginFieldType.values) {
      if (v.name == raw) return v;
    }
    throw PluginManifestException('Unknown field type "$raw"');
  }
}

/// A single configurable input — used both for global plugin settings and for
/// per-action fields.
class PluginField {
  final String key;
  final PluginFieldType type;
  final String label;
  final dynamic defaultValue;

  /// Static select options (each `{value,label}`), when provided.
  final List<PluginFieldOption> options;

  /// Id of a dynamic [PluginListDef] supplying this select's options at runtime.
  final String? optionsFrom;

  PluginField({
    required this.key,
    required this.type,
    required this.label,
    this.defaultValue,
    this.options = const [],
    this.optionsFrom,
  });

  factory PluginField.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String?;
    if (key == null || key.isEmpty) {
      throw PluginManifestException('Field is missing "key"');
    }
    final typeRaw = json['type'] as String?;
    if (typeRaw == null) {
      throw PluginManifestException('Field "$key" is missing "type"');
    }
    return PluginField(
      key: key,
      type: PluginFieldType.parse(typeRaw),
      label: json['label'] as String? ?? key,
      defaultValue: json['default'],
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => PluginFieldOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      optionsFrom: json['optionsFrom'] as String?,
    );
  }
}

/// One choice in a select field.
class PluginFieldOption {
  final String value;
  final String label;
  PluginFieldOption({required this.value, required this.label});

  factory PluginFieldOption.fromJson(Map<String, dynamic> json) {
    final value = (json['value'] ?? '').toString();
    return PluginFieldOption(
      value: value,
      label: json['label'] as String? ?? value,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

/// An action the plugin exposes; becomes a selectable action in the button
/// editor.
class PluginActionDef {
  final String id;
  final String name;
  final String? icon;
  final List<PluginField> fields;

  PluginActionDef({
    required this.id,
    required this.name,
    this.icon,
    this.fields = const [],
  });

  factory PluginActionDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw PluginManifestException('Action is missing "id"');
    }
    return PluginActionDef(
      id: id,
      name: json['name'] as String? ?? id,
      icon: json['icon'] as String?,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => PluginField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// A live value the plugin streams (for live tiles).
class PluginStateDef {
  final String id;
  final String label;
  final String type;

  PluginStateDef({required this.id, required this.label, this.type = 'string'});

  factory PluginStateDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw PluginManifestException('State is missing "id"');
    }
    return PluginStateDef(
      id: id,
      label: json['label'] as String? ?? id,
      type: json['type'] as String? ?? 'string',
    );
  }
}

/// A dynamic option source the plugin answers at runtime.
class PluginListDef {
  final String id;
  final String label;

  PluginListDef({required this.id, required this.label});

  factory PluginListDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw PluginManifestException('List is missing "id"');
    }
    return PluginListDef(id: id, label: json['label'] as String? ?? id);
  }
}

/// A ready-made button the plugin suggests. Surfaced in the add-button picker
/// while the plugin is enabled (and hidden when it's disabled), so users can
/// drop in working plugin buttons without configuring them by hand.
///
/// A preset is one of:
///   - an *action* button when [actionId] is set (invokes that plugin action),
///   - a *live tile* when [stateId] is set (binds the button to that state).
class PluginPresetDef {
  final String name;
  final String? icon; // icon code point string; falls back to a default
  final String? color; // hex; falls back to a default
  final String? actionId;
  final String? stateId;

  PluginPresetDef({
    required this.name,
    this.icon,
    this.color,
    this.actionId,
    this.stateId,
  });

  factory PluginPresetDef.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    if (name == null || name.isEmpty) {
      throw PluginManifestException('Preset is missing "name"');
    }
    final actionId = json['actionId'] as String?;
    final stateId = json['stateId'] as String?;
    if ((actionId == null || actionId.isEmpty) &&
        (stateId == null || stateId.isEmpty)) {
      throw PluginManifestException(
          'Preset "$name" needs either "actionId" or "stateId"');
    }
    return PluginPresetDef(
      name: name,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      actionId: actionId,
      stateId: stateId,
    );
  }
}

/// The fully parsed and validated plugin manifest.
class PluginManifest {
  /// Highest plugin protocol/manifest version this host understands. A plugin
  /// declaring a higher `apiVersion` is rejected (it expects features we lack).
  static const int supportedApiVersion = 1;

  final String id;
  final String name;
  final String version;
  final String author;
  final int apiVersion;
  final Map<String, String> run;
  final List<PluginField> settings;
  final List<PluginActionDef> actions;
  final List<PluginStateDef> states;
  final List<PluginListDef> lists;
  final List<PluginPresetDef> presets;

  PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.apiVersion,
    required this.run,
    this.settings = const [],
    this.actions = const [],
    this.states = const [],
    this.lists = const [],
    this.presets = const [],
  });

  /// The launch command for [platform] (e.g. `'windows'`), or null if the plugin
  /// does not support it.
  String? runCommandFor(String platform) => run[platform];

  PluginActionDef? action(String actionId) {
    for (final a in actions) {
      if (a.id == actionId) return a;
    }
    return null;
  }

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw PluginManifestException('Manifest is missing required "id"');
    }
    final runRaw = json['run'];
    if (runRaw is! Map) {
      throw PluginManifestException('Manifest "$id" is missing required "run"');
    }
    final run = <String, String>{};
    runRaw.forEach((k, v) {
      if (v is String && v.isNotEmpty) run[k.toString()] = v;
    });
    if (run.isEmpty) {
      throw PluginManifestException(
        'Manifest "$id" "run" has no platform commands',
      );
    }

    final apiVersion = (json['apiVersion'] as num?)?.toInt() ?? 1;
    if (apiVersion > supportedApiVersion) {
      throw PluginManifestException(
        'Manifest "$id" targets apiVersion $apiVersion but this host supports '
        'up to $supportedApiVersion',
      );
    }

    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final list = json[key] as List<dynamic>?;
      if (list == null) return const [];
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return PluginManifest(
      id: id,
      name: json['name'] as String? ?? id,
      version: json['version'] as String? ?? '0.0.0',
      author: json['author'] as String? ?? 'Unknown',
      apiVersion: apiVersion,
      run: run,
      settings: parseList('settings', PluginField.fromJson),
      actions: parseList('actions', PluginActionDef.fromJson),
      states: parseList('states', PluginStateDef.fromJson),
      lists: parseList('lists', PluginListDef.fromJson),
      presets: parseList('presets', PluginPresetDef.fromJson),
    );
  }
}
