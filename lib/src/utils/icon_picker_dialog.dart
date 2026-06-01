import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A dialog that displays a searchable grid of Font Awesome icons
class IconPickerDialog extends StatefulWidget {
  /// Creates a new icon picker dialog
  const IconPickerDialog({super.key});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<MapEntry<String, FaIconData>> _allIcons = [];

  @override
  void initState() {
    super.initState();
    _loadIcons();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads all the Font Awesome icons into the list
  void _loadIcons() {
    // Create a map of named icons
    final iconsMap = <String, FaIconData>{};

    // INTERFACE ICONS
    iconsMap['home'] = FontAwesomeIcons.house;
    iconsMap['cog'] = FontAwesomeIcons.gear;
    iconsMap['settings'] = FontAwesomeIcons.gear;
    iconsMap['gear'] = FontAwesomeIcons.gear;
    iconsMap['wrench'] = FontAwesomeIcons.wrench;
    iconsMap['tools'] = FontAwesomeIcons.screwdriverWrench;
    iconsMap['sign-in'] = FontAwesomeIcons.rightToBracket;
    iconsMap['login'] = FontAwesomeIcons.rightToBracket;
    iconsMap['sign-out'] = FontAwesomeIcons.rightFromBracket;
    iconsMap['logout'] = FontAwesomeIcons.rightFromBracket;
    iconsMap['user'] = FontAwesomeIcons.user;
    iconsMap['profile'] = FontAwesomeIcons.user;
    iconsMap['users'] = FontAwesomeIcons.users;
    iconsMap['search'] = FontAwesomeIcons.magnifyingGlass;
    iconsMap['plus'] = FontAwesomeIcons.plus;
    iconsMap['add'] = FontAwesomeIcons.plus;
    iconsMap['minus'] = FontAwesomeIcons.minus;
    iconsMap['remove'] = FontAwesomeIcons.minus;
    iconsMap['times'] = FontAwesomeIcons.xmark;
    iconsMap['close'] = FontAwesomeIcons.xmark;
    iconsMap['check'] = FontAwesomeIcons.check;
    iconsMap['arrow-left'] = FontAwesomeIcons.arrowLeft;
    iconsMap['arrow-right'] = FontAwesomeIcons.arrowRight;
    iconsMap['arrow-up'] = FontAwesomeIcons.arrowUp;
    iconsMap['arrow-down'] = FontAwesomeIcons.arrowDown;

    // MEDIA CONTROLS
    iconsMap['play'] = FontAwesomeIcons.play;
    iconsMap['pause'] = FontAwesomeIcons.pause;
    iconsMap['stop'] = FontAwesomeIcons.stop;
    iconsMap['forward'] = FontAwesomeIcons.forward;
    iconsMap['backward'] = FontAwesomeIcons.backward;
    iconsMap['step-forward'] = FontAwesomeIcons.forwardStep;
    iconsMap['step-backward'] = FontAwesomeIcons.backwardStep;
    iconsMap['fast-forward'] = FontAwesomeIcons.forwardFast;
    iconsMap['fast-backward'] = FontAwesomeIcons.backwardFast;
    iconsMap['volume-up'] = FontAwesomeIcons.volumeHigh;
    iconsMap['volume-down'] = FontAwesomeIcons.volumeLow;
    iconsMap['volume-off'] = FontAwesomeIcons.volumeOff;
    iconsMap['volume-mute'] = FontAwesomeIcons.volumeXmark;
    iconsMap['music'] = FontAwesomeIcons.music;
    iconsMap['video'] = FontAwesomeIcons.video;
    iconsMap['audio'] = FontAwesomeIcons.music;
    iconsMap['camera'] = FontAwesomeIcons.camera;
    iconsMap['microphone'] = FontAwesomeIcons.microphone;
    iconsMap['mic'] = FontAwesomeIcons.microphone;
    iconsMap['headphones'] = FontAwesomeIcons.headphones;
    iconsMap['eject'] = FontAwesomeIcons.eject;
    iconsMap['record'] = FontAwesomeIcons.circle;

    // DEVICES & HARDWARE
    iconsMap['computer'] = FontAwesomeIcons.computer;
    iconsMap['desktop'] = FontAwesomeIcons.desktop;
    iconsMap['laptop'] = FontAwesomeIcons.laptop;
    iconsMap['mobile'] = FontAwesomeIcons.mobileScreen;
    iconsMap['tablet'] = FontAwesomeIcons.tablet;
    iconsMap['tv'] = FontAwesomeIcons.tv;
    iconsMap['display'] = FontAwesomeIcons.display;
    iconsMap['keyboard'] = FontAwesomeIcons.keyboard;
    iconsMap['mouse'] = FontAwesomeIcons.computerMouse;
    iconsMap['gamepad'] = FontAwesomeIcons.gamepad;
    iconsMap['power'] = FontAwesomeIcons.powerOff;
    iconsMap['shutdown'] = FontAwesomeIcons.powerOff;
    iconsMap['battery-full'] = FontAwesomeIcons.batteryFull;
    iconsMap['battery-half'] = FontAwesomeIcons.batteryHalf;
    iconsMap['battery-quarter'] = FontAwesomeIcons.batteryQuarter;
    iconsMap['battery-low'] = FontAwesomeIcons.batteryQuarter;
    iconsMap['usb'] = FontAwesomeIcons.usb;
    iconsMap['bluetooth'] = FontAwesomeIcons.bluetooth;
    iconsMap['wifi'] = FontAwesomeIcons.wifi;
    iconsMap['signal'] = FontAwesomeIcons.signal;

    // DOCUMENTS & FILES
    iconsMap['file'] = FontAwesomeIcons.file;
    iconsMap['document'] = FontAwesomeIcons.fileLines;
    iconsMap['folder'] = FontAwesomeIcons.folder;
    iconsMap['folder-open'] = FontAwesomeIcons.folderOpen;
    iconsMap['save'] = FontAwesomeIcons.floppyDisk;
    iconsMap['copy'] = FontAwesomeIcons.copy;
    iconsMap['paste'] = FontAwesomeIcons.paste;
    iconsMap['cut'] = FontAwesomeIcons.scissors;
    iconsMap['upload'] = FontAwesomeIcons.upload;
    iconsMap['download'] = FontAwesomeIcons.download;
    iconsMap['trash'] = FontAwesomeIcons.trash;
    iconsMap['delete'] = FontAwesomeIcons.trash;
    iconsMap['pen'] = FontAwesomeIcons.pen;
    iconsMap['pencil'] = FontAwesomeIcons.pencil;
    iconsMap['edit'] = FontAwesomeIcons.penToSquare;
    iconsMap['print'] = FontAwesomeIcons.print;

    // WEB & COMMUNICATION
    iconsMap['globe'] = FontAwesomeIcons.globe;
    iconsMap['earth'] = FontAwesomeIcons.earthAmericas;
    iconsMap['browser'] = FontAwesomeIcons.globe;
    iconsMap['link'] = FontAwesomeIcons.link;
    iconsMap['unlink'] = FontAwesomeIcons.linkSlash;
    iconsMap['share'] = FontAwesomeIcons.share;
    iconsMap['email'] = FontAwesomeIcons.envelope;
    iconsMap['mail'] = FontAwesomeIcons.envelope;
    iconsMap['inbox'] = FontAwesomeIcons.inbox;
    iconsMap['message'] = FontAwesomeIcons.message;
    iconsMap['chat'] = FontAwesomeIcons.comment;
    iconsMap['comments'] = FontAwesomeIcons.comments;
    iconsMap['phone'] = FontAwesomeIcons.phone;
    iconsMap['call'] = FontAwesomeIcons.phone;

    // SYSTEM & SERVER
    iconsMap['server'] = FontAwesomeIcons.server;
    iconsMap['database'] = FontAwesomeIcons.database;
    iconsMap['cloud'] = FontAwesomeIcons.cloud;
    iconsMap['cloud-upload'] = FontAwesomeIcons.cloudArrowUp;
    iconsMap['cloud-download'] = FontAwesomeIcons.cloudArrowDown;
    iconsMap['sync'] = FontAwesomeIcons.arrowsRotate;
    iconsMap['refresh'] = FontAwesomeIcons.arrowsRotate;
    iconsMap['reload'] = FontAwesomeIcons.arrowsRotate;
    iconsMap['undo'] = FontAwesomeIcons.arrowRotateLeft;
    iconsMap['redo'] = FontAwesomeIcons.arrowRotateRight;
    iconsMap['code'] = FontAwesomeIcons.code;
    iconsMap['terminal'] = FontAwesomeIcons.terminal;
    iconsMap['command'] = FontAwesomeIcons.terminal;
    iconsMap['lock'] = FontAwesomeIcons.lock;
    iconsMap['unlock'] = FontAwesomeIcons.unlock;
    iconsMap['key'] = FontAwesomeIcons.key;

    // CONTENT & TEXT
    iconsMap['image'] = FontAwesomeIcons.image;
    iconsMap['photo'] = FontAwesomeIcons.image;
    iconsMap['picture'] = FontAwesomeIcons.image;
    iconsMap['gallery'] = FontAwesomeIcons.images;
    iconsMap['align-left'] = FontAwesomeIcons.alignLeft;
    iconsMap['align-center'] = FontAwesomeIcons.alignCenter;
    iconsMap['align-right'] = FontAwesomeIcons.alignRight;
    iconsMap['align-justify'] = FontAwesomeIcons.alignJustify;
    iconsMap['bold'] = FontAwesomeIcons.bold;
    iconsMap['italic'] = FontAwesomeIcons.italic;
    iconsMap['underline'] = FontAwesomeIcons.underline;
    iconsMap['strikethrough'] = FontAwesomeIcons.strikethrough;
    iconsMap['list'] = FontAwesomeIcons.list;
    iconsMap['list-ol'] = FontAwesomeIcons.listOl;
    iconsMap['list-ul'] = FontAwesomeIcons.listUl;
    iconsMap['table'] = FontAwesomeIcons.table;
    iconsMap['font'] = FontAwesomeIcons.font;

    // UI & INTERFACE
    iconsMap['bell'] = FontAwesomeIcons.bell;
    iconsMap['notification'] = FontAwesomeIcons.bell;
    iconsMap['calendar'] = FontAwesomeIcons.calendar;
    iconsMap['calendar-days'] = FontAwesomeIcons.calendarDays;
    iconsMap['clock'] = FontAwesomeIcons.clock;
    iconsMap['time'] = FontAwesomeIcons.clock;
    iconsMap['map'] = FontAwesomeIcons.map;
    iconsMap['location'] = FontAwesomeIcons.locationDot;
    iconsMap['bookmark'] = FontAwesomeIcons.bookmark;
    iconsMap['tag'] = FontAwesomeIcons.tag;
    iconsMap['tags'] = FontAwesomeIcons.tags;
    iconsMap['expand'] = FontAwesomeIcons.expand;
    iconsMap['compress'] = FontAwesomeIcons.compress;
    iconsMap['filter'] = FontAwesomeIcons.filter;
    iconsMap['sort'] = FontAwesomeIcons.arrowDownWideShort;
    iconsMap['sliders'] = FontAwesomeIcons.sliders;

    // SOCIAL & EMOTIONS
    iconsMap['thumbs-up'] = FontAwesomeIcons.thumbsUp;
    iconsMap['like'] = FontAwesomeIcons.thumbsUp;
    iconsMap['thumbs-down'] = FontAwesomeIcons.thumbsDown;
    iconsMap['dislike'] = FontAwesomeIcons.thumbsDown;
    iconsMap['heart'] = FontAwesomeIcons.heart;
    iconsMap['love'] = FontAwesomeIcons.heart;
    iconsMap['star'] = FontAwesomeIcons.star;
    iconsMap['favorite'] = FontAwesomeIcons.star;
    iconsMap['smile'] = FontAwesomeIcons.faceSmile;
    iconsMap['frown'] = FontAwesomeIcons.faceFrown;
    iconsMap['meh'] = FontAwesomeIcons.faceMeh;
    iconsMap['laugh'] = FontAwesomeIcons.faceGrinSquint;
    iconsMap['angry'] = FontAwesomeIcons.faceAngry;

    // MISCELLANEOUS
    iconsMap['shopping-cart'] = FontAwesomeIcons.cartShopping;
    iconsMap['cart'] = FontAwesomeIcons.cartShopping;
    iconsMap['credit-card'] = FontAwesomeIcons.creditCard;
    iconsMap['money'] = FontAwesomeIcons.moneyBill;
    iconsMap['lightbulb'] = FontAwesomeIcons.lightbulb;
    iconsMap['idea'] = FontAwesomeIcons.lightbulb;
    iconsMap['flag'] = FontAwesomeIcons.flag;
    iconsMap['fire'] = FontAwesomeIcons.fire;
    iconsMap['magic'] = FontAwesomeIcons.wandMagicSparkles;
    iconsMap['gift'] = FontAwesomeIcons.gift;

    // Add additional categories and icons as needed

    // Convert Map to List of MapEntry for better handling in widgets
    setState(() {
      _allIcons.addAll(iconsMap.entries.toList());
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<MapEntry<String, FaIconData>> get _filteredIcons {
    if (_searchQuery.isEmpty) {
      return _allIcons;
    }
    return _allIcons
        .where((entry) => entry.key.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select an Icon',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Icons',
                hintText: 'Type to search (e.g., play, power, volume)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
              ),
            ),
            const SizedBox(height: 16),

            // Icons grid
            Expanded(
              child:
                  _filteredIcons.isEmpty
                      ? const Center(child: Text('No icons found'))
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _filteredIcons.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredIcons[index];
                          return InkWell(
                            onTap: () {
                              // Return the underlying IconData so callers can
                              // keep working with plain IconData.
                              Navigator.of(context).pop(entry.value.data);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(entry.value, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  entry.key.length > 10
                                      ? '${entry.key.substring(0, 8)}...'
                                      : entry.key,
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
