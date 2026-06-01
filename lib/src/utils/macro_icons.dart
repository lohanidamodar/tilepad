import 'package:flutter/widgets.dart';
import 'package:picons/picons.dart';

/// Centralised icon system shared by the client and the server.
///
/// Buttons persist their icon as a Phosphor code-point string. All rendering
/// goes through [resolve] and all pickers are built from [picker], so the two
/// apps stay visually identical and there is a single place to evolve the icon
/// set.
class MacroIcons {
  MacroIcons._();

  static const String _fontFamily = 'PhosphorRegular';
  static const String _fontPackage = 'picons';

  /// Neutral icon shown for unknown or legacy icon identifiers.
  static const IconData fallback = PiconsRegular.squaresFour;

  /// Reconstructs an [IconData] from a persisted [iconName] (a Phosphor code
  /// point). Falls back to [fallback] for empty/legacy/unparseable values.
  static IconData resolve(String iconName) {
    final codePoint = int.tryParse(iconName);
    if (codePoint != null && codePoint > 0) {
      return IconData(
        codePoint,
        fontFamily: _fontFamily,
        fontPackage: _fontPackage,
      );
    }
    return fallback;
  }

  /// The identifier to persist for a picker [icon].
  static String idFor(IconData icon) => icon.codePoint.toString();

  /// The default icon identifier for a brand-new button.
  static String get defaultId => idFor(PiconsRegular.lightbulb);

  /// A compact set of common icons offered as quick presets in the editors.
  static const List<IconData> presets = [
    PiconsRegular.lightbulb,
    PiconsRegular.desktop,
    PiconsRegular.play,
    PiconsRegular.stop,
    PiconsRegular.speakerHigh,
    PiconsRegular.speakerX,
    PiconsRegular.monitor,
    PiconsRegular.fire,
    PiconsRegular.power,
    PiconsRegular.appWindow,
    PiconsRegular.folderOpen,
    PiconsRegular.terminal,
    PiconsRegular.arrowsClockwise,
    PiconsRegular.arrowCounterClockwise,
    PiconsRegular.keyboard,
    PiconsRegular.camera,
    PiconsRegular.envelope,
    PiconsRegular.pencilSimple,
    PiconsRegular.code,
    PiconsRegular.globe,
  ];

  /// Curated, searchable Phosphor icons for the icon picker.
  ///
  /// Keyed by a searchable term (several terms may map to one icon, mirroring
  /// how people look for icons). Order is roughly by category for nicer
  /// browsing when no search is active.
  static const Map<String, IconData> picker = {
    // Interface
    'home': PiconsRegular.house,
    'settings': PiconsRegular.gearSix,
    'gear': PiconsRegular.gearSix,
    'wrench': PiconsRegular.wrench,
    'tools': PiconsRegular.toolbox,
    'sign in': PiconsRegular.signIn,
    'login': PiconsRegular.signIn,
    'sign out': PiconsRegular.signOut,
    'logout': PiconsRegular.signOut,
    'user': PiconsRegular.user,
    'profile': PiconsRegular.user,
    'users': PiconsRegular.users,
    'search': PiconsRegular.magnifyingGlass,
    'add': PiconsRegular.plus,
    'plus': PiconsRegular.plus,
    'remove': PiconsRegular.minus,
    'minus': PiconsRegular.minus,
    'close': PiconsRegular.x,
    'check': PiconsRegular.check,
    'arrow left': PiconsRegular.arrowLeft,
    'arrow right': PiconsRegular.arrowRight,
    'arrow up': PiconsRegular.arrowUp,
    'arrow down': PiconsRegular.arrowDown,

    // Media controls
    'play': PiconsRegular.play,
    'pause': PiconsRegular.pause,
    'stop': PiconsRegular.stop,
    'next': PiconsRegular.skipForward,
    'previous': PiconsRegular.skipBack,
    'fast forward': PiconsRegular.fastForward,
    'rewind': PiconsRegular.rewind,
    'eject': PiconsRegular.eject,
    'volume up': PiconsRegular.speakerHigh,
    'volume down': PiconsRegular.speakerLow,
    'mute': PiconsRegular.speakerX,
    'music': PiconsRegular.musicNotes,
    'audio': PiconsRegular.musicNotes,
    'video': PiconsRegular.videoCamera,
    'camera': PiconsRegular.camera,
    'microphone': PiconsRegular.microphone,
    'mic off': PiconsRegular.microphoneSlash,
    'headphones': PiconsRegular.headphones,
    'image': PiconsRegular.image,
    'photo': PiconsRegular.image,
    'gallery': PiconsRegular.images,

    // Devices & hardware
    'monitor': PiconsRegular.monitor,
    'desktop': PiconsRegular.desktop,
    'laptop': PiconsRegular.laptop,
    'mobile': PiconsRegular.deviceMobile,
    'tv': PiconsRegular.television,
    'keyboard': PiconsRegular.keyboard,
    'mouse': PiconsRegular.mouse,
    'gamepad': PiconsRegular.gameController,
    'power': PiconsRegular.power,
    'shutdown': PiconsRegular.power,
    'battery': PiconsRegular.batteryFull,
    'usb': PiconsRegular.usb,
    'bluetooth': PiconsRegular.bluetooth,
    'wifi': PiconsRegular.wifiHigh,

    // Files & documents
    'file': PiconsRegular.file,
    'files': PiconsRegular.files,
    'folder': PiconsRegular.folder,
    'folder open': PiconsRegular.folderOpen,
    'save': PiconsRegular.floppyDisk,
    'copy': PiconsRegular.copy,
    'paste': PiconsRegular.clipboard,
    'cut': PiconsRegular.scissors,
    'upload': PiconsRegular.uploadSimple,
    'download': PiconsRegular.downloadSimple,
    'trash': PiconsRegular.trash,
    'delete': PiconsRegular.trash,
    'edit': PiconsRegular.pencilSimple,
    'pen': PiconsRegular.pencil,
    'print': PiconsRegular.printer,
    'note': PiconsRegular.notePencil,

    // Web & communication
    'globe': PiconsRegular.globe,
    'browser': PiconsRegular.browser,
    'link': PiconsRegular.link,
    'share': PiconsRegular.shareNetwork,
    'email': PiconsRegular.envelope,
    'mail': PiconsRegular.envelope,
    'chat': PiconsRegular.chatCircle,
    'comments': PiconsRegular.chats,
    'phone': PiconsRegular.phone,

    // System & dev
    'server': PiconsRegular.desktop,
    'database': PiconsRegular.database,
    'cloud': PiconsRegular.cloud,
    'cloud upload': PiconsRegular.cloudArrowUp,
    'sync': PiconsRegular.arrowsClockwise,
    'refresh': PiconsRegular.arrowsClockwise,
    'undo': PiconsRegular.arrowCounterClockwise,
    'redo': PiconsRegular.arrowClockwise,
    'code': PiconsRegular.code,
    'terminal': PiconsRegular.terminal,
    'command': PiconsRegular.terminal,
    'lock': PiconsRegular.lock,
    'unlock': PiconsRegular.lockOpen,
    'key': PiconsRegular.key,

    // Text & layout
    'align left': PiconsRegular.textAlignLeft,
    'align center': PiconsRegular.textAlignCenter,
    'align right': PiconsRegular.textAlignRight,
    'bold': PiconsRegular.textB,
    'italic': PiconsRegular.textItalic,
    'underline': PiconsRegular.textUnderline,
    'list': PiconsRegular.list,
    'numbered list': PiconsRegular.listNumbers,
    'table': PiconsRegular.table,

    // UI
    'bell': PiconsRegular.bell,
    'notification': PiconsRegular.bell,
    'calendar': PiconsRegular.calendar,
    'clock': PiconsRegular.clock,
    'time': PiconsRegular.clock,
    'location': PiconsRegular.mapPin,
    'bookmark': PiconsRegular.bookmark,
    'tag': PiconsRegular.tag,
    'filter': PiconsRegular.funnel,
    'sliders': PiconsRegular.slidersHorizontal,
    'grid': PiconsRegular.squaresFour,

    // Social & symbols
    'like': PiconsRegular.thumbsUp,
    'dislike': PiconsRegular.thumbsDown,
    'heart': PiconsRegular.heart,
    'favorite': PiconsRegular.star,
    'star': PiconsRegular.star,
    'smile': PiconsRegular.smiley,
    'sad': PiconsRegular.smileySad,
    'cart': PiconsRegular.shoppingCart,
    'card': PiconsRegular.creditCard,
    'money': PiconsRegular.money,
    'idea': PiconsRegular.lightbulb,
    'lightbulb': PiconsRegular.lightbulb,
    'flag': PiconsRegular.flag,
    'fire': PiconsRegular.fire,
    'magic': PiconsRegular.magicWand,
    'gift': PiconsRegular.gift,
  };
}
