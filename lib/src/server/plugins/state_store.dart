import 'dart:async';

/// The latest live value for one `(pluginId, stateId)` pair.
class StateEntry {
  final String pluginId;
  final String stateId;
  final dynamic value;

  /// Optional icon/image payload (icon name or data URI) for live icon tiles.
  final String? image;

  StateEntry({
    required this.pluginId,
    required this.stateId,
    this.value,
    this.image,
  });

  Map<String, dynamic> toJson() => {
        'pluginId': pluginId,
        'stateId': stateId,
        'value': value,
        if (image != null) 'image': image,
      };
}

/// In-memory store of the latest value per plugin state, with a change stream
/// the server uses to forward updates to phone clients.
class StateStore {
  final Map<String, StateEntry> _entries = {};
  final _controller = StreamController<StateEntry>.broadcast();

  String _key(String pluginId, String stateId) => '$pluginId/$stateId';

  /// Stream of entries as they change.
  Stream<StateEntry> get changes => _controller.stream;

  /// Sets (or replaces) a state value, emitting on [changes].
  void set(String pluginId, String stateId, {dynamic value, String? image}) {
    // Skip unchanged values: sampled states (clock, active window, metrics)
    // are written every tick but change far less often, and every emission is
    // broadcast to all clients.
    final existing = _entries[_key(pluginId, stateId)];
    if (existing != null &&
        existing.value == value &&
        existing.image == image) {
      return;
    }
    final entry = StateEntry(
      pluginId: pluginId,
      stateId: stateId,
      value: value,
      image: image,
    );
    _entries[_key(pluginId, stateId)] = entry;
    _controller.add(entry);
  }

  StateEntry? get(String pluginId, String stateId) =>
      _entries[_key(pluginId, stateId)];

  /// All current entries (used to replay state to a newly connected client).
  List<StateEntry> snapshot() => List.unmodifiable(_entries.values);

  /// Drops all entries belonging to [pluginId] (e.g. when it is disabled).
  void clearPlugin(String pluginId) {
    _entries.removeWhere((_, entry) => entry.pluginId == pluginId);
  }

  void dispose() {
    _controller.close();
  }
}
