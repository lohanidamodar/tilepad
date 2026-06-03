// Pure protocol helpers for the OBS plugin: OBS-WebSocket v5 authentication and
// message building, plus event→state mapping. No `dart:io` so it can be unit
// tested from the main app's test suite and reused by `plugin.dart`.
//
// OBS-WebSocket v5 reference: https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md
import 'dart:convert';
import 'dart:typed_data';

/// OBS opcodes.
class ObsOp {
  static const hello = 0;
  static const identify = 1;
  static const identified = 2;
  static const event = 5;
  static const request = 6;
  static const requestResponse = 7;
}

/// Event categories we subscribe to: Scenes (4) | Outputs (64) so we receive
/// CurrentProgramSceneChanged, RecordStateChanged and StreamStateChanged.
const int obsEventSubscriptions = 4 | 64;

/// Computes the OBS-WebSocket v5 authentication string from the Hello
/// challenge/salt and the password:
///   secret = base64(sha256(password + salt))
///   auth   = base64(sha256(secret + challenge))
String obsAuthString(String password, String salt, String challenge) {
  final secret = base64.encode(sha256Bytes(utf8.encode(password + salt)));
  return base64.encode(sha256Bytes(utf8.encode(secret + challenge)));
}

/// Builds the Identify (op 1) payload. [auth] is null when OBS has no password.
Map<String, dynamic> buildIdentify(String? auth) => {
      'op': ObsOp.identify,
      'd': {
        'rpcVersion': 1,
        'authentication': ?auth,
        'eventSubscriptions': obsEventSubscriptions,
      },
    };

/// Builds a Request (op 6) payload.
Map<String, dynamic> buildRequest(
  String requestType,
  String requestId, [
  Map<String, dynamic>? data,
]) =>
    {
      'op': ObsOp.request,
      'd': {
        'requestType': requestType,
        'requestId': requestId,
        'requestData': ?data,
      },
    };

/// The action id → OBS request mapping for the simple (no-data) actions.
const Map<String, String> obsActionRequests = {
  'toggle_record': 'ToggleRecord',
  'start_record': 'StartRecord',
  'stop_record': 'StopRecord',
  'toggle_stream': 'ToggleStream',
  'start_stream': 'StartStream',
  'stop_stream': 'StopStream',
};

/// A live-state update derived from an OBS event, or null if the event isn't
/// one we surface. Returns (stateId, value).
({String id, String value})? stateFromEvent(
    String eventType, Map<String, dynamic> data) {
  switch (eventType) {
    case 'CurrentProgramSceneChanged':
      final name = data['sceneName'] as String?;
      return name == null ? null : (id: 'scene', value: name);
    case 'RecordStateChanged':
      return (
        id: 'recording',
        value: (data['outputActive'] as bool? ?? false) ? '● REC' : 'Idle',
      );
    case 'StreamStateChanged':
      return (
        id: 'streaming',
        value: (data['outputActive'] as bool? ?? false) ? '● LIVE' : 'Offline',
      );
    default:
      return null;
  }
}

/// Pretty labels for the recording/streaming booleans (used for initial poll).
String recordingLabel(bool active) => active ? '● REC' : 'Idle';
String streamingLabel(bool active) => active ? '● LIVE' : 'Offline';

// --- SHA-256 (FIPS 180-4) -------------------------------------------------
// Self-contained so the plugin needs no pub packages. Verified against the
// standard test vectors in obs_protocol_test.dart.

final List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

/// Computes the SHA-256 digest of [message] as 32 bytes.
Uint8List sha256Bytes(List<int> message) {
  var h0 = 0x6a09e667,
      h1 = 0xbb67ae85,
      h2 = 0x3c6ef372,
      h3 = 0xa54ff53a,
      h4 = 0x510e527f,
      h5 = 0x9b05688c,
      h6 = 0x1f83d9ab,
      h7 = 0x5be0cd19;

  // Pre-processing: pad to a multiple of 64 bytes.
  final ml = message.length * 8;
  final bytes = <int>[...message, 0x80];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    bytes.add((ml >> (i * 8)) & 0xff);
  }

  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < bytes.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunk + i * 4;
      w[i] = (bytes[j] << 24) |
          (bytes[j + 1] << 16) |
          (bytes[j + 2] << 8) |
          bytes[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }

    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  final out = Uint8List(32);
  final hs = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (var i = 0; i < 8; i++) {
    out[i * 4] = (hs[i] >> 24) & 0xff;
    out[i * 4 + 1] = (hs[i] >> 16) & 0xff;
    out[i * 4 + 2] = (hs[i] >> 8) & 0xff;
    out[i * 4 + 3] = hs[i] & 0xff;
  }
  return out;
}

/// SHA-256 as a lowercase hex string (used by tests).
String sha256Hex(List<int> message) =>
    sha256Bytes(message).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
