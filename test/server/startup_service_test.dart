import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilepad/src/server/services/startup_service.dart';

void main() {
  group('StartupService on Linux', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('tilepad_startup_test');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    StartupService service({Map<String, String>? env}) => StartupService(
          operatingSystem: 'linux',
          executable: '/opt/tile pad/tilepad',
          environment: env ?? {'XDG_CONFIG_HOME': temp.path},
        );

    test('enable writes an autostart .desktop entry, disable removes it',
        () async {
      final svc = service();
      expect(await svc.isEnabled(), isFalse);

      expect(await svc.setEnabled(true), isTrue);
      expect(await svc.isEnabled(), isTrue);
      final contents =
          File('${temp.path}/autostart/tilepad.desktop').readAsStringSync();
      expect(contents, contains('[Desktop Entry]'));
      expect(contents, contains('Name=Tilepad'));
      // Quoted so a path with spaces survives the Exec field, plus the flag
      // that makes a login launch start in the tray.
      expect(contents, contains('Exec="/opt/tile pad/tilepad" --hidden'));

      expect(await svc.setEnabled(false), isTrue);
      expect(await svc.isEnabled(), isFalse);
      expect(File('${temp.path}/autostart/tilepad.desktop').existsSync(),
          isFalse);
    });

    test('disable is a no-op when no entry exists', () async {
      expect(await service().setEnabled(false), isTrue);
    });

    test('falls back to ~/.config when XDG_CONFIG_HOME is unset', () {
      final svc = service(env: {'HOME': temp.path});
      expect(svc.linuxDesktopFile().path,
          '${temp.path}/.config/autostart/tilepad.desktop');
    });
  });

  group('StartupService on macOS', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('tilepad_startup_test');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('enable writes a RunAtLoad LaunchAgent plist for the executable',
        () async {
      final svc = StartupService(
        operatingSystem: 'macos',
        executable: '/Applications/Tilepad & Co.app/Contents/MacOS/tilepad',
        environment: {'HOME': temp.path},
      );
      expect(await svc.setEnabled(true), isTrue);
      expect(await svc.isEnabled(), isTrue);

      final plist = File(
              '${temp.path}/Library/LaunchAgents/dev.appwriters.tilepad.plist')
          .readAsStringSync();
      expect(plist, contains('<string>dev.appwriters.tilepad</string>'));
      expect(plist, contains('<key>RunAtLoad</key>'));
      // XML-escaped executable path.
      expect(
          plist,
          contains(
              '<string>/Applications/Tilepad &amp; Co.app/Contents/MacOS/tilepad</string>'));
      // A login launch starts in the tray.
      expect(plist, contains('<string>--hidden</string>'));

      expect(await svc.setEnabled(false), isTrue);
      expect(await svc.isEnabled(), isFalse);
    });
  });

  group('StartupService on Windows', () {
    test('uses reg add/query/delete on the HKCU Run key', () async {
      final calls = <List<String>>[];
      var queryExit = 1; // value absent
      final svc = StartupService(
        operatingSystem: 'windows',
        executable: r'C:\Program Files\Tilepad\tilepad.exe',
        environment: const {},
        runProcess: (cmd, args) async {
          calls.add([cmd, ...args]);
          final exit = args.first == 'query' ? queryExit : 0;
          return ProcessResult(0, exit, '', '');
        },
      );

      expect(await svc.isEnabled(), isFalse);
      expect(await svc.setEnabled(true), isTrue);
      queryExit = 0;
      expect(await svc.isEnabled(), isTrue);
      expect(await svc.setEnabled(false), isTrue);

      const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
      expect(calls[1], [
        'reg', 'add', key,
        '/v', 'Tilepad',
        '/t', 'REG_SZ',
        // Quoted, as Run entries expect for paths with spaces, plus the flag
        // that makes a login launch start in the tray.
        '/d', r'"C:\Program Files\Tilepad\tilepad.exe" --hidden',
        '/f',
      ]);
      expect(calls[3], ['reg', 'delete', key, '/v', 'Tilepad', '/f']);
      expect(calls.every((c) => c.first == 'reg'), isTrue);
    });

    test('deleting an absent entry still reports the desired state', () async {
      final svc = StartupService(
        operatingSystem: 'windows',
        executable: r'C:\tilepad.exe',
        environment: const {},
        // `reg delete` fails when the value doesn't exist; the follow-up
        // query also reports it absent — which is what "disabled" means.
        runProcess: (cmd, args) async => ProcessResult(0, 1, '', ''),
      );
      expect(await svc.setEnabled(false), isTrue);
    });
  });
}
