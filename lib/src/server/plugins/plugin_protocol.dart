/// Wire-protocol message type constants for the plugin <-> host WebSocket.
///
/// Messages are JSON objects with a `type` field. See `docs/plugins/protocol.md`
/// for the full reference. Kept as plain string constants so plugin authors in
/// any language can match them exactly.
class PluginProtocol {
  PluginProtocol._();

  /// Protocol version the host implements. A plugin's `apiVersion` must be <=.
  static const int version = 1;

  // Plugin -> Host
  static const String register = 'register';
  static const String actionResult = 'actionResult';
  static const String listResult = 'listResult';
  static const String setState = 'setState';
  static const String setStateImage = 'setStateImage';
  static const String log = 'log';

  // Host -> Plugin
  static const String registered = 'registered';
  static const String invoke = 'invoke';
  static const String requestList = 'requestList';
  static const String settingsUpdated = 'settingsUpdated';
  static const String shutdown = 'shutdown';
}
