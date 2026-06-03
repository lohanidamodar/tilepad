import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

// Imported via relative path: the plugin is a standalone script outside the
// app package, but its pure protocol helpers use only dart:core/convert.
import '../../assets/plugins/obs/obs_protocol.dart';

void main() {
  group('SHA-256 (NIST vectors)', () {
    test('empty string', () {
      expect(sha256Hex(utf8.encode('')),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('"abc"', () {
      expect(sha256Hex(utf8.encode('abc')),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });

    test('multi-block message', () {
      expect(
        sha256Hex(utf8.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });
  });

  group('OBS WebSocket v5 auth', () {
    // The OBS v5 spec defines the auth string as:
    //   secret = base64(sha256(password + salt))
    //   auth   = base64(sha256(secret + challenge))
    // We pin that exact two-step composition (anchored on the NIST-verified
    // sha256 above), which catches arg-order or single-vs-double-hash bugs.
    test('follows the documented salt-then-challenge composition', () {
      const password = 'supersecretpassword';
      const salt = 'lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=';
      const challenge = '+IxH4CnCiqpX1rM9scsNynZzbOe4Wkc9_OOAoZmgcdU=';

      final secret = base64.encode(sha256Bytes(utf8.encode(password + salt)));
      final expected =
          base64.encode(sha256Bytes(utf8.encode(secret + challenge)));

      expect(obsAuthString(password, salt, challenge), expected);
      // A SHA-256 digest base64-encodes to 44 characters.
      expect(obsAuthString(password, salt, challenge).length, 44);
    });

    test('salt and challenge are not interchangeable', () {
      final a = obsAuthString('pw', 'saltAAAA', 'chalBBBB');
      final b = obsAuthString('pw', 'chalBBBB', 'saltAAAA');
      expect(a, isNot(b));
    });
  });

  group('message builders', () {
    test('identify carries rpcVersion, subscriptions and optional auth', () {
      final withAuth = buildIdentify('abc');
      expect(withAuth['op'], ObsOp.identify);
      expect(withAuth['d']['rpcVersion'], 1);
      expect(withAuth['d']['authentication'], 'abc');
      expect(withAuth['d']['eventSubscriptions'], obsEventSubscriptions);

      final noAuth = buildIdentify(null);
      expect(noAuth['d'].containsKey('authentication'), isFalse);
    });

    test('request carries type, id and optional data', () {
      final r = buildRequest('SetCurrentProgramScene', 'r1', {'sceneName': 'Cam'});
      expect(r['op'], ObsOp.request);
      expect(r['d']['requestType'], 'SetCurrentProgramScene');
      expect(r['d']['requestId'], 'r1');
      expect(r['d']['requestData']['sceneName'], 'Cam');

      expect(buildRequest('ToggleRecord', 'r2')['d'].containsKey('requestData'),
          isFalse);
    });
  });

  group('event → state mapping', () {
    test('scene change', () {
      final s = stateFromEvent('CurrentProgramSceneChanged', {'sceneName': 'Intro'});
      expect(s!.id, 'scene');
      expect(s.value, 'Intro');
    });

    test('record + stream state', () {
      expect(stateFromEvent('RecordStateChanged', {'outputActive': true})!.value,
          '● REC');
      expect(stateFromEvent('RecordStateChanged', {'outputActive': false})!.value,
          'Idle');
      expect(stateFromEvent('StreamStateChanged', {'outputActive': true})!.value,
          '● LIVE');
    });

    test('unrelated events are ignored', () {
      expect(stateFromEvent('InputVolumeMeters', const {}), isNull);
    });
  });
}
