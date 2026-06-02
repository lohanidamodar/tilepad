import 'package:flutter_test/flutter_test.dart';
import 'package:marco_deck/src/models/button.dart';
import 'package:marco_deck/src/server/command_executor.dart';
import 'package:marco_deck/src/server/plugins/plugin_host.dart';

void main() {
  group('CommandExecutor plugin routing', () {
    test('routes a plugin action to the injected invoker', () async {
      String? gotPlugin;
      String? gotAction;
      Map<String, dynamic>? gotSettings;

      final executor = CommandExecutor()
        ..pluginInvoker = (pluginId, actionId, settings) async {
          gotPlugin = pluginId;
          gotAction = actionId;
          gotSettings = settings;
          return PluginActionResult(success: true, output: 'ok');
        };

      final action = ButtonAction(
        type: ActionType.plugin,
        pluginId: 'com.you.obs',
        pluginActionId: 'switch_scene',
        settings: {'scene': 'Intro'},
      );

      final result = await executor.executeAction(action);

      expect(result.success, isTrue);
      expect(result.output, 'ok');
      expect(gotPlugin, 'com.you.obs');
      expect(gotAction, 'switch_scene');
      expect(gotSettings, {'scene': 'Intro'});
    });

    test('returns a failure when no plugin host is wired', () async {
      final executor = CommandExecutor();
      final action = ButtonAction(
        type: ActionType.plugin,
        pluginId: 'com.you.obs',
        pluginActionId: 'switch_scene',
      );
      final result = await executor.executeAction(action);
      expect(result.success, isFalse);
      expect(result.error.toLowerCase(), contains('plugin'));
    });

    test('maps an invoker failure to a failed CommandResult', () async {
      final executor = CommandExecutor()
        ..pluginInvoker = (_, __, ___) async =>
            PluginActionResult(success: false, error: 'boom');
      final action = ButtonAction(
        type: ActionType.plugin,
        pluginId: 'p',
        pluginActionId: 'a',
      );
      final result = await executor.executeAction(action);
      expect(result.success, isFalse);
      expect(result.error, 'boom');
    });
  });
}
