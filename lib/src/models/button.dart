import 'package:uuid/uuid.dart';

/// Defines the types of actions a button can perform
enum ActionType {
  /// Execute a custom shell command
  command,

  /// Execute a predefined command from the list
  commandPreset,

  /// Send keystroke(s) to the system
  keystroke,

  /// Prompt the client for text at press time, then type it on the server
  promptText,

  /// Prompt the client for a key combination at press time, then send it
  promptKeystroke,

  /// Let the client pick one of the server's open windows to bring to front
  selectWindow,

  /// Open a URL / website in the default browser (target in [ButtonAction.command])
  openUrl,

  /// Press a media transport / volume key (key name in [ButtonAction.key]:
  /// playPause, next, previous, stop, mute, volumeUp, volumeDown)
  mediaKey,

  /// Switch the client's visible page (target in [ButtonAction.command]:
  /// next, prev, first, last, or `page:<pageId>` for a specific page).
  /// Handled entirely on the client.
  navigatePage,

  /// Invoke an action provided by an installed plugin
  plugin,

  /// Pause for a number of milliseconds (in [ButtonAction.command]) before
  /// the next action in a multi-action sequence runs.
  delay,
}

/// Represents a single action that can be performed by a button
class ButtonAction {
  /// Unique identifier for the action
  final String id;

  /// Type of this action
  ActionType type;

  /// Command to execute (for command and commandPreset types)
  String command;

  /// Key to press (for keystroke type)
  String key;

  /// Modifier keys to hold while pressing the key (for keystroke type)
  /// Can include: ctrl, alt, shift, meta/win
  List<String> modifiers;

  /// Plugin id that owns this action (for [ActionType.plugin]).
  String pluginId;

  /// The plugin's action id to invoke (for [ActionType.plugin]).
  String pluginActionId;

  /// Field values for the plugin action (for [ActionType.plugin]).
  Map<String, dynamic> settings;

  /// Creates a new button action with the given properties
  ButtonAction({
    String? id,
    required this.type,
    this.command = '',
    this.key = '',
    this.modifiers = const [],
    this.pluginId = '',
    this.pluginActionId = '',
    Map<String, dynamic>? settings,
  })  : id = id ?? const Uuid().v4(),
        settings = settings ?? <String, dynamic>{};

  /// Creates a button action from a JSON map
  factory ButtonAction.fromJson(Map<String, dynamic> json) {
    return ButtonAction(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: ActionType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => ActionType.command,
      ),
      command: json['command'] as String? ?? '',
      key: json['key'] as String? ?? '',
      modifiers:
          (json['modifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      pluginId: json['pluginId'] as String? ?? '',
      pluginActionId: json['pluginActionId'] as String? ?? '',
      settings:
          (json['settings'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }

  /// Deep-copies this action (same id) so editors can mutate a working copy
  /// without touching the stored button until save.
  ButtonAction copy() {
    return ButtonAction(
      id: id,
      type: type,
      command: command,
      key: key,
      modifiers: List<String>.from(modifiers),
      pluginId: pluginId,
      pluginActionId: pluginActionId,
      settings: Map<String, dynamic>.from(settings),
    );
  }

  /// Converts this action to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'command': command,
      'key': key,
      'modifiers': modifiers,
      // Plugin fields are written only when relevant to keep legacy JSON clean.
      if (type == ActionType.plugin) 'pluginId': pluginId,
      if (type == ActionType.plugin) 'pluginActionId': pluginActionId,
      if (settings.isNotEmpty) 'settings': settings,
    };
  }
}

/// Whether a live plugin state drives a button's title text or its icon.
enum StateBindingMode { title, icon }

/// Binds a button to a live plugin state so the client renders a "live tile".
class StateBinding {
  final String pluginId;
  final String stateId;
  final StateBindingMode mode;

  StateBinding({
    required this.pluginId,
    required this.stateId,
    this.mode = StateBindingMode.title,
  });

  factory StateBinding.fromJson(Map<String, dynamic> json) {
    return StateBinding(
      pluginId: json['pluginId'] as String? ?? '',
      stateId: json['stateId'] as String? ?? '',
      mode: StateBindingMode.values.firstWhere(
        (e) => e.name == (json['mode'] as String?),
        orElse: () => StateBindingMode.title,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'pluginId': pluginId,
        'stateId': stateId,
        'mode': mode.name,
      };
}

/// The second face of a toggle button: its appearance and the actions that
/// run when the button is pressed while in the "on" state.
class ToggleState {
  /// Display name shown while toggled on (empty = keep the primary name).
  String name;

  /// Icon shown while toggled on (empty = keep the primary icon).
  String iconName;

  /// Background color while toggled on (empty = keep the primary color).
  String color;

  /// Actions to run when pressed while toggled on (empty = run the primary
  /// actions for both states).
  List<ButtonAction> actions;

  ToggleState({
    this.name = '',
    this.iconName = '',
    this.color = '',
    List<ButtonAction>? actions,
  }) : actions = actions ?? [];

  factory ToggleState.fromJson(Map<String, dynamic> json) {
    return ToggleState(
      name: json['name'] as String? ?? '',
      iconName: json['iconName'] as String? ?? '',
      color: json['color'] as String? ?? '',
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => ButtonAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'iconName': iconName,
        'color': color,
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

/// Represents a custom button that can be displayed on the client
/// and configured from the server.
class Button {
  /// Unique identifier for the button
  final String id;

  /// Display name of the button
  String name;

  /// Icon identifier (corresponds to an icon in the Flutter library)
  String iconName;

  /// List of actions to perform when the button is pressed
  List<ButtonAction> actions;

  /// Background color of the button (in hex format)
  String color;

  /// Optional binding to a live plugin state. When set, the client renders this
  /// button as a "live tile" driven by the bound state.
  StateBinding? stateBinding;

  /// Optional second face for a toggle button. When set, the button alternates
  /// between its primary face and this one on each press; the server tracks
  /// and persists which face is active in [toggled].
  ToggleState? toggleState;

  /// Whether a toggle button is currently showing its second face. Runtime
  /// state owned by the server, persisted so it survives restarts, and sent to
  /// clients so they render the active face.
  bool toggled;

  /// Actions to run when the button is held (long-pressed) on the client
  /// instead of tapped. Empty = long press does nothing special.
  List<ButtonAction> longPressActions;

  // The following properties are kept for backward compatibility
  // and convenience when dealing with a single action

  /// Type of action this button performs (for backward compatibility)
  ButtonType get type =>
      actions.isNotEmpty
          ? _convertActionType(actions.first.type)
          : ButtonType.command;

  /// Command to execute when the button is pressed (for backward compatibility)
  String get command => actions.isNotEmpty ? actions.first.command : '';

  /// Key to press (for backward compatibility)
  String get key => actions.isNotEmpty ? actions.first.key : '';

  /// Modifier keys to hold while pressing the key (for backward compatibility)
  List<String> get modifiers =>
      actions.isNotEmpty ? actions.first.modifiers : const [];

  /// The prompt action type if this button asks the client for input at press
  /// time ([ActionType.promptText] or [ActionType.promptKeystroke]); otherwise
  /// null.
  ActionType? get promptActionType {
    if (actions.isEmpty) return null;
    final type = actions.first.type;
    return (type == ActionType.promptText ||
            type == ActionType.promptKeystroke ||
            type == ActionType.selectWindow)
        ? type
        : null;
  }

  /// Whether this button prompts the client for input at press time.
  bool get isPrompt => promptActionType != null;

  /// The page-navigation target if this button's first action is
  /// [ActionType.navigatePage] (e.g. "next", "prev", "first", "last");
  /// otherwise null. Navigation is performed locally on the client.
  String? get navigationTarget {
    if (actions.isEmpty) return null;
    final action = actions.first;
    return action.type == ActionType.navigatePage ? action.command : null;
  }

  /// The name to render given the current toggle face.
  String get effectiveName =>
      (toggled && toggleState != null && toggleState!.name.isNotEmpty)
          ? toggleState!.name
          : name;

  /// The icon to render given the current toggle face.
  String get effectiveIconName =>
      (toggled && toggleState != null && toggleState!.iconName.isNotEmpty)
          ? toggleState!.iconName
          : iconName;

  /// The color to render given the current toggle face.
  String get effectiveColor =>
      (toggled && toggleState != null && toggleState!.color.isNotEmpty)
          ? toggleState!.color
          : color;

  /// The actions to run for the current toggle face.
  List<ButtonAction> get effectiveActions =>
      (toggled && toggleState != null && toggleState!.actions.isNotEmpty)
          ? toggleState!.actions
          : actions;

  /// Creates a new button with the given properties
  Button({
    String? id,
    required this.name,
    required this.iconName,
    List<ButtonAction>? actions,
    ButtonType? type,
    String command = '',
    String key = '',
    List<String> modifiers = const [],
    this.color = '#4285F4', // Default Google blue
    this.stateBinding,
    this.toggleState,
    this.toggled = false,
    List<ButtonAction>? longPressActions,
  }) : id = id ?? const Uuid().v4(),
       actions = actions ?? [],
       longPressActions = longPressActions ?? [] {
    // If actions weren't provided but type was, create a legacy-style action
    if (this.actions.isEmpty && type != null) {
      this.actions.add(
        ButtonAction(
          type: _convertButtonType(type),
          command: command,
          key: key,
          modifiers: modifiers,
        ),
      );
    }
  }

  /// Creates a button from a JSON map
  factory Button.fromJson(Map<String, dynamic> json) {
    // Check if the JSON has the new actions array
    final actionsList = json['actions'] as List<dynamic>?;

    final stateBindingJson = json['stateBinding'] as Map<String, dynamic>?;
    final stateBinding =
        stateBindingJson != null ? StateBinding.fromJson(stateBindingJson) : null;

    final toggleStateJson = json['toggleState'] as Map<String, dynamic>?;
    final toggleState =
        toggleStateJson != null ? ToggleState.fromJson(toggleStateJson) : null;
    final toggled = json['toggled'] as bool? ?? false;
    final longPressActions = (json['longPressActions'] as List<dynamic>?)
            ?.map((a) => ButtonAction.fromJson(a as Map<String, dynamic>))
            .toList() ??
        <ButtonAction>[];

    if (actionsList != null) {
      // New format with multiple actions
      return Button(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String,
        actions:
            actionsList
                .map(
                  (actionJson) =>
                      ButtonAction.fromJson(actionJson as Map<String, dynamic>),
                )
                .toList(),
        color: json['color'] as String? ?? '#4285F4',
        stateBinding: stateBinding,
        toggleState: toggleState,
        toggled: toggled,
        longPressActions: longPressActions,
      );
    } else {
      // Legacy format with a single action
      return Button(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String,
        type: ButtonType.values.firstWhere(
          (e) => e.name == (json['type'] as String?),
          orElse: () => ButtonType.command,
        ),
        command: json['command'] as String? ?? '',
        key: json['key'] as String? ?? '',
        modifiers:
            (json['modifiers'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        color: json['color'] as String? ?? '#4285F4',
        stateBinding: stateBinding,
        toggleState: toggleState,
        toggled: toggled,
        longPressActions: longPressActions,
      );
    }
  }

  /// Converts this button to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'actions': actions.map((action) => action.toJson()).toList(),
      'color': color,
      if (stateBinding != null) 'stateBinding': stateBinding!.toJson(),
      if (toggleState != null) 'toggleState': toggleState!.toJson(),
      if (toggleState != null) 'toggled': toggled,
      if (longPressActions.isNotEmpty)
        'longPressActions':
            longPressActions.map((action) => action.toJson()).toList(),
    };
  }

  /// Deep-copies this button as a NEW library button (fresh id, name suffixed
  /// with "copy", toggle reset to the primary face).
  Button duplicate() {
    return Button(
      name: '$name copy',
      iconName: iconName,
      color: color,
      actions: actions.map((a) => a.copy()).toList(),
      stateBinding: stateBinding == null
          ? null
          : StateBinding(
              pluginId: stateBinding!.pluginId,
              stateId: stateBinding!.stateId,
              mode: stateBinding!.mode,
            ),
      toggleState: toggleState == null
          ? null
          : ToggleState(
              name: toggleState!.name,
              iconName: toggleState!.iconName,
              color: toggleState!.color,
              actions: toggleState!.actions.map((a) => a.copy()).toList(),
            ),
      longPressActions: longPressActions.map((a) => a.copy()).toList(),
    );
  }

  /// Helper method to convert ActionType to ButtonType
  ButtonType _convertActionType(ActionType actionType) {
    switch (actionType) {
      case ActionType.command:
        return ButtonType.command;
      case ActionType.commandPreset:
        return ButtonType.commandPreset;
      case ActionType.keystroke:
        return ButtonType.keystroke;
      case ActionType.promptText:
        return ButtonType.promptText;
      case ActionType.promptKeystroke:
        return ButtonType.promptKeystroke;
      case ActionType.selectWindow:
        return ButtonType.selectWindow;
      // Action types added after the legacy ButtonType enum was frozen map to
      // the generic `command` slot — `type` exists only for backward compat.
      case ActionType.openUrl:
      case ActionType.mediaKey:
      case ActionType.navigatePage:
      case ActionType.delay:
        return ButtonType.command;
      case ActionType.plugin:
        return ButtonType.plugin;
    }
  }

  /// Helper method to convert ButtonType to ActionType
  ActionType _convertButtonType(ButtonType buttonType) {
    switch (buttonType) {
      case ButtonType.command:
        return ActionType.command;
      case ButtonType.commandPreset:
        return ActionType.commandPreset;
      case ButtonType.keystroke:
        return ActionType.keystroke;
      case ButtonType.promptText:
        return ActionType.promptText;
      case ButtonType.promptKeystroke:
        return ActionType.promptKeystroke;
      case ButtonType.selectWindow:
        return ActionType.selectWindow;
      case ButtonType.plugin:
        return ActionType.plugin;
    }
  }
}

/// A placement of a library [Button] on a page's spanning grid.
///
/// Carries the resolved [button] (so the wire payload and UI render directly)
/// plus the per-placement size in grid cells.
class Tile {
  /// Unique identifier for this placement.
  final String id;

  /// Id of the library button this tile places.
  final String buttonId;

  /// Width in grid columns.
  int colSpan;

  /// Height in grid rows.
  int rowSpan;

  /// The resolved button definition.
  Button button;

  Tile({
    String? id,
    required this.button,
    this.colSpan = 1,
    this.rowSpan = 1,
  })  : id = id ?? const Uuid().v4(),
        buttonId = button.id;

  factory Tile.fromJson(Map<String, dynamic> json) {
    return Tile(
      id: json['id'] as String?,
      button: Button.fromJson(json['button'] as Map<String, dynamic>),
      colSpan: json['colSpan'] as int? ?? 1,
      rowSpan: json['rowSpan'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
        'button': button.toJson(),
      };
}

/// A page: a spanning grid of [Tile] placements.
class Page {
  /// Unique identifier for the page.
  final String id;

  /// Display name of the page.
  String name;

  /// Order of the page (for sorting).
  int order;

  /// Number of grid columns the page is laid out on.
  int columns;

  /// Tiles placed on this page, in flow order.
  List<Tile> tiles;

  Page({
    String? id,
    required this.name,
    this.order = 0,
    this.columns = 4,
    List<Tile>? tiles,
  })  : id = id ?? const Uuid().v4(),
        tiles = tiles ?? [];

  factory Page.fromJson(Map<String, dynamic> json) {
    return Page(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled',
      order: json['order'] as int? ?? 0,
      columns: json['columns'] as int? ?? 4,
      tiles: (json['tiles'] as List<dynamic>?)
              ?.map((t) => Tile.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'columns': columns,
        'tiles': tiles.map((t) => t.toJson()).toList(),
      };
}

/// Legacy enum type - kept for backward compatibility
enum ButtonType {
  /// Execute a custom shell command
  command,

  /// Execute a predefined command from the list
  commandPreset,

  /// Send keystroke(s) to the system
  keystroke,

  /// Prompt the client for text at press time, then type it on the server
  promptText,

  /// Prompt the client for a key combination at press time, then send it
  promptKeystroke,

  /// Let the client pick one of the server's open windows to bring to front
  selectWindow,

  /// Invoke an action provided by an installed plugin
  plugin,
}
