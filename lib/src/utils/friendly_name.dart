import 'dart:math';

/// Generates friendly, human-readable device/server names such as
/// "Swift Falcon 42". Shared by the client and the server so both halves of
/// the app name themselves the same way.
String generateFriendlyName() {
  const adjectives = [
    'Swift',
    'Bright',
    'Cool',
    'Quick',
    'Smart',
    'Bold',
    'Neat',
    'Fast',
    'Sleek',
    'Sharp',
  ];
  const nouns = [
    'Falcon',
    'Tiger',
    'Eagle',
    'Phoenix',
    'Dragon',
    'Wolf',
    'Hawk',
    'Lion',
    'Panther',
    'Cobra',
  ];

  final random = Random();
  final adjective = adjectives[random.nextInt(adjectives.length)];
  final noun = nouns[random.nextInt(nouns.length)];
  final number = random.nextInt(100);

  return '$adjective $noun $number';
}
