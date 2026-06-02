/// A top-level window reported by the server, offered to the client so it can
/// pick one to bring to the foreground.
class WindowInfo {
  /// Opaque identifier for the window (the native handle on the server).
  final String id;

  /// The window's title as shown to the user.
  final String title;

  /// Creates a window info.
  const WindowInfo({required this.id, required this.title});

  /// Creates a window info from a JSON map.
  factory WindowInfo.fromJson(Map<String, dynamic> json) => WindowInfo(
        id: json['id'].toString(),
        title: (json['title'] as String?) ?? '',
      );

  /// Converts this window info to a JSON map.
  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}
