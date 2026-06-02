import 'package:flutter/material.dart';

import '../design/design.dart';

/// A modifier key option shown as a selectable chip.
class _ModifierOption {
  final String name;
  final String value;
  final IconData icon;
  const _ModifierOption(this.name, this.value, this.icon);
}

/// Modifier options, shared so the client picker matches the server's action
/// editor exactly.
const List<_ModifierOption> _modifierOptions = [
  _ModifierOption('Ctrl', 'ctrl', Icons.keyboard_control_key),
  _ModifierOption('Alt', 'alt', Icons.keyboard_alt_outlined),
  _ModifierOption('Shift', 'shift', Icons.keyboard_arrow_up),
  _ModifierOption('Win/Meta', 'meta', Icons.window_outlined),
];

/// The set of keys offered for a key combination. Common named keys are listed
/// first so they're easy to find without scrolling past the whole alphabet.
const List<String> kComboKeys = [
  'enter', 'tab', 'space', 'esc', 'backspace', 'delete', //
  'up', 'down', 'left', 'right', 'home', 'end', 'pageup', 'pagedown',
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11', 'f12',
];

/// A reusable picker for a key combination — modifier chips plus a key
/// dropdown, with a live preview. Used by the client's dynamic key button and
/// mirrors the server's action editor.
class KeyComboPicker extends StatefulWidget {
  /// Creates a key combination picker.
  const KeyComboPicker({
    super.key,
    required this.initialKey,
    required this.initialModifiers,
    required this.onChanged,
  });

  /// The initially selected key.
  final String initialKey;

  /// The initially selected modifiers.
  final Set<String> initialModifiers;

  /// Called whenever the selected key or modifiers change.
  final void Function(String key, Set<String> modifiers) onChanged;

  @override
  State<KeyComboPicker> createState() => _KeyComboPickerState();
}

class _KeyComboPickerState extends State<KeyComboPicker> {
  late String _key = widget.initialKey;
  late final Set<String> _modifiers = {...widget.initialModifiers};

  void _notify() => widget.onChanged(_key, _modifiers);

  String get _preview {
    final mods = _modifiers
        .map((m) => _modifierOptions.firstWhere((o) => o.value == m).name)
        .join(' + ');
    final keyName = _key.toUpperCase();
    return mods.isNotEmpty ? '$mods + $keyName' : keyName;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: tokens.space.md,
            horizontal: tokens.space.xl,
          ),
          decoration: BoxDecoration(
            color: tokens.color.accentSubtle,
            borderRadius: tokens.radius.brSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard, color: tokens.color.accent),
              SizedBox(width: tokens.space.md),
              Flexible(
                child: Text(
                  _preview,
                  style: AppTypography.mono(
                    fontSize: tokens.typeScale.body,
                    fontWeight: tokens.typeScale.wBold,
                    color: tokens.color.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.space.xl),
        Text('Modifiers', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.space.sm),
        Wrap(
          spacing: tokens.space.sm,
          runSpacing: tokens.space.sm,
          children:
              _modifierOptions.map((mod) {
                final selected = _modifiers.contains(mod.value);
                return FilterChip(
                  avatar: Icon(mod.icon, size: tokens.icon.sm),
                  label: Text(mod.name),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _modifiers.add(mod.value);
                      } else {
                        _modifiers.remove(mod.value);
                      }
                    });
                    _notify();
                  },
                );
              }).toList(),
        ),
        SizedBox(height: tokens.space.xl),
        Text('Key', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: tokens.space.sm),
        DropdownButtonFormField<String>(
          initialValue: _key,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items:
              kComboKeys
                  .map(
                    (k) => DropdownMenuItem<String>(
                      value: k,
                      child: Text(k.toUpperCase()),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _key = value);
              _notify();
            }
          },
        ),
      ],
    );
  }
}
