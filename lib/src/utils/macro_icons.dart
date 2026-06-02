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

  static const String _fontFamily = 'PhosphorBold';
  static const String _fontPackage = 'picons';

  /// Neutral icon shown for unknown or legacy icon identifiers.
  static const IconData fallback = PiconsBold.squaresFour;

  /// Reconstructs an [IconData] from a persisted [iconName] (a Phosphor code
  /// point). Falls back to [fallback] for empty/legacy/unparseable values.
  static IconData resolve(String iconName) {
    final codePoint = int.tryParse(iconName);
    if (codePoint != null && codePoint > 0) {
      return IconData(
        // Icons are stored dynamically (a parsed code point), so this cannot
        // be a const argument; tree-shaking is disabled via build flags.
        // ignore: non_const_argument_for_const_parameter
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
  static String get defaultId => idFor(PiconsBold.lightbulb);

  /// A compact set of common icons offered as quick presets in the editors.
  static const List<IconData> presets = [
    PiconsBold.lightbulb,
    PiconsBold.desktop,
    PiconsBold.play,
    PiconsBold.stop,
    PiconsBold.speakerHigh,
    PiconsBold.speakerX,
    PiconsBold.monitor,
    PiconsBold.fire,
    PiconsBold.power,
    PiconsBold.appWindow,
    PiconsBold.folderOpen,
    PiconsBold.terminal,
    PiconsBold.arrowsClockwise,
    PiconsBold.arrowCounterClockwise,
    PiconsBold.keyboard,
    PiconsBold.camera,
    PiconsBold.envelope,
    PiconsBold.pencilSimple,
    PiconsBold.code,
    PiconsBold.globe,
  ];

  /// Curated, searchable Phosphor icons for the icon picker.
  ///
  /// Keyed by a searchable term (several terms may map to one icon, mirroring
  /// how people look for icons). Order is roughly by category for nicer
  /// browsing when no search is active.
  static const Map<String, IconData> picker = {
    // Interface
    'home': PiconsBold.house,
    'settings': PiconsBold.gearSix,
    'gear': PiconsBold.gearSix,
    'wrench': PiconsBold.wrench,
    'tools': PiconsBold.toolbox,
    'sign in': PiconsBold.signIn,
    'login': PiconsBold.signIn,
    'sign out': PiconsBold.signOut,
    'logout': PiconsBold.signOut,
    'user': PiconsBold.user,
    'profile': PiconsBold.user,
    'users': PiconsBold.users,
    'search': PiconsBold.magnifyingGlass,
    'add': PiconsBold.plus,
    'plus': PiconsBold.plus,
    'remove': PiconsBold.minus,
    'minus': PiconsBold.minus,
    'close': PiconsBold.x,
    'check': PiconsBold.check,
    'arrow left': PiconsBold.arrowLeft,
    'arrow right': PiconsBold.arrowRight,
    'arrow up': PiconsBold.arrowUp,
    'arrow down': PiconsBold.arrowDown,

    // Media controls
    'play': PiconsBold.play,
    'pause': PiconsBold.pause,
    'stop': PiconsBold.stop,
    'next': PiconsBold.skipForward,
    'previous': PiconsBold.skipBack,
    'fast forward': PiconsBold.fastForward,
    'rewind': PiconsBold.rewind,
    'eject': PiconsBold.eject,
    'volume up': PiconsBold.speakerHigh,
    'volume down': PiconsBold.speakerLow,
    'mute': PiconsBold.speakerX,
    'music': PiconsBold.musicNotes,
    'audio': PiconsBold.musicNotes,
    'video': PiconsBold.videoCamera,
    'camera': PiconsBold.camera,
    'microphone': PiconsBold.microphone,
    'mic off': PiconsBold.microphoneSlash,
    'headphones': PiconsBold.headphones,
    'image': PiconsBold.image,
    'photo': PiconsBold.image,
    'gallery': PiconsBold.images,

    // Devices & hardware
    'monitor': PiconsBold.monitor,
    'desktop': PiconsBold.desktop,
    'laptop': PiconsBold.laptop,
    'mobile': PiconsBold.deviceMobile,
    'tv': PiconsBold.television,
    'keyboard': PiconsBold.keyboard,
    'mouse': PiconsBold.mouse,
    'gamepad': PiconsBold.gameController,
    'power': PiconsBold.power,
    'shutdown': PiconsBold.power,
    'battery': PiconsBold.batteryFull,
    'usb': PiconsBold.usb,
    'bluetooth': PiconsBold.bluetooth,
    'wifi': PiconsBold.wifiHigh,

    // Files & documents
    'file': PiconsBold.file,
    'files': PiconsBold.files,
    'folder': PiconsBold.folder,
    'folder open': PiconsBold.folderOpen,
    'save': PiconsBold.floppyDisk,
    'copy': PiconsBold.copy,
    'paste': PiconsBold.clipboard,
    'cut': PiconsBold.scissors,
    'upload': PiconsBold.uploadSimple,
    'download': PiconsBold.downloadSimple,
    'trash': PiconsBold.trash,
    'delete': PiconsBold.trash,
    'edit': PiconsBold.pencilSimple,
    'pen': PiconsBold.pencil,
    'print': PiconsBold.printer,
    'note': PiconsBold.notePencil,

    // Web & communication
    'globe': PiconsBold.globe,
    'browser': PiconsBold.browser,
    'link': PiconsBold.link,
    'share': PiconsBold.shareNetwork,
    'email': PiconsBold.envelope,
    'mail': PiconsBold.envelope,
    'chat': PiconsBold.chatCircle,
    'comments': PiconsBold.chats,
    'phone': PiconsBold.phone,

    // System & dev
    'server': PiconsBold.desktop,
    'database': PiconsBold.database,
    'cloud': PiconsBold.cloud,
    'cloud upload': PiconsBold.cloudArrowUp,
    'sync': PiconsBold.arrowsClockwise,
    'refresh': PiconsBold.arrowsClockwise,
    'undo': PiconsBold.arrowCounterClockwise,
    'redo': PiconsBold.arrowClockwise,
    'code': PiconsBold.code,
    'terminal': PiconsBold.terminal,
    'command': PiconsBold.terminal,
    'lock': PiconsBold.lock,
    'unlock': PiconsBold.lockOpen,
    'key': PiconsBold.key,

    // Text & layout
    'align left': PiconsBold.textAlignLeft,
    'align center': PiconsBold.textAlignCenter,
    'align right': PiconsBold.textAlignRight,
    'bold': PiconsBold.textB,
    'italic': PiconsBold.textItalic,
    'underline': PiconsBold.textUnderline,
    'list': PiconsBold.list,
    'numbered list': PiconsBold.listNumbers,
    'table': PiconsBold.table,

    // UI
    'bell': PiconsBold.bell,
    'notification': PiconsBold.bell,
    'calendar': PiconsBold.calendar,
    'clock': PiconsBold.clock,
    'time': PiconsBold.clock,
    'location': PiconsBold.mapPin,
    'bookmark': PiconsBold.bookmark,
    'tag': PiconsBold.tag,
    'filter': PiconsBold.funnel,
    'sliders': PiconsBold.slidersHorizontal,
    'grid': PiconsBold.squaresFour,

    // Social & symbols
    'like': PiconsBold.thumbsUp,
    'dislike': PiconsBold.thumbsDown,
    'heart': PiconsBold.heart,
    'favorite': PiconsBold.star,
    'star': PiconsBold.star,
    'smile': PiconsBold.smiley,
    'sad': PiconsBold.smileySad,
    'cart': PiconsBold.shoppingCart,
    'card': PiconsBold.creditCard,
    'money': PiconsBold.money,
    'idea': PiconsBold.lightbulb,
    'lightbulb': PiconsBold.lightbulb,
    'flag': PiconsBold.flag,
    'fire': PiconsBold.fire,
    'magic': PiconsBold.magicWand,
    'gift': PiconsBold.gift,
  };
}
