// Compiles the bundled first-party plugins to a native executable for the host
// platform, so release builds run them without a Dart SDK on the user's PATH.
//
// Run whenever a bundled plugin's source changes, before `flutter build`:
//   dart run tool/build_plugins.dart
//
// Cross-platform binaries (macOS/Linux) are produced by running this on each
// platform (e.g. in CI); `dart compile exe` only targets the host OS.
import 'dart:io';

/// folder → output binary base name (extension added per-platform).
const _plugins = {
  'assets/plugins/obs': 'obs-plugin',
};

Future<void> main() async {
  final ext = Platform.isWindows ? '.exe' : '';
  for (final entry in _plugins.entries) {
    final src = '${entry.key}/plugin.dart';
    final out = '${entry.key}/${entry.value}$ext';
    stdout.writeln('Compiling $src -> $out');
    final result =
        await Process.run('dart', ['compile', 'exe', src, '-o', out]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stderr.writeln('Failed to compile ${entry.key}');
      exit(result.exitCode);
    }
  }
  stdout.writeln('Done.');
}
