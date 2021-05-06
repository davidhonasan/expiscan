import 'dart:math';

import 'package:flutter/material.dart';
import 'package:expiscan/constants/constants.dart';
import 'package:expiscan/widgets.dart';
import 'package:expiscan/service/notification_service.dart';
import 'package:expiscan/service/database_service.dart';

// Screens
import 'package:expiscan/screens/items_page.dart';
import 'package:expiscan/screens/pantry_page.dart';
import 'package:expiscan/screens/settings_page.dart';
import 'package:expiscan/screens/scan_page.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initTz();
  initNotificationService();
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpiScan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _pageIndex = 0;
  // bool _isFabClosed = true;
  int _filterPantryId = 0;

  final PageController controller = PageController(initialPage: 0);

  // void _onFabChanged(bool value) {
  //   _isFabClosed = value;
  //   setState(() {});
  // }

  void _onPageChanged(int index) {
    _pageIndex = index;
    setState(() {});
  }

  void _onBottomNavbarChanged(int index) {
    controller.animateToPage(index,
        duration: Duration(milliseconds: 400), curve: Curves.ease);
  }

  void _showFilterPopup() {
    int _tempFilterPantryId = _filterPantryId;

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Filter Food\'s Pantry'),
              scrollable: true,
              content: FutureBuilder(
                  future: ExpiscanDB.getEntries(pantryTableName),
                  builder: (context, AsyncSnapshot snapshot) {
                    if (snapshot.hasData &&
                        snapshot.connectionState == ConnectionState.done) {
                      List<dynamic> entry = snapshot.data!;
                      entry.insert(
                          0, Pantry(id: 0, name: 'No Filter', picturePath: ''));

                      return StatefulBuilder(
                        builder: (context, setState) => Container(
                          height: MediaQuery.of(context).size.height / 4,
                          width: double.maxFinite,
                          child: Scrollbar(
                            child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: entry.length,
                                itemBuilder: (context, index) {
                                  return RadioListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(entry[index].name),
                                      value: entry[index].id,
                                      groupValue: _tempFilterPantryId,
                                      onChanged: (dynamic value) {
                                        setState(() {
                                          _tempFilterPantryId = value;
                                        });
                                      });
                                }),
                          ),
                        ),
                      );
                    } else {
                      return EmptyListPage(
                        phrase: 'Pantry',
                      );
                    }
                  }),
              actions: [
                TextButton(
                    onPressed: Navigator.of(context).pop,
                    child: Text('CANCEL')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _filterPantryId = _tempFilterPantryId;
                      setState(() {});
                    },
                    child: Text('SET'))
              ],
            ));
  }

  Widget _changeTitle() {
    switch (_pageIndex) {
      case 0:
        return Text('Foods');
      case 1:
        return Text('Pantries');
      case 2:
        return Text('Settings');
      default:
        return Text('Expiscan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Scaffold(
        appBar: AppBar(
          title: _changeTitle(),
          brightness: Brightness.dark,
          actions: <Widget>[
            Visibility(
                child: Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.filter_list_rounded),
                        onPressed: _showFilterPopup),
                    // IconButton(
                    //     icon: Icon(Icons.search),
                    //     tooltip: 'Search',
                    //     onPressed: null)
                  ],
                ),
                visible: _pageIndex == 0 ? true : false),
          ],
        ),
        body: PageView(
          scrollDirection: Axis.horizontal,
          controller: controller,
          children: <Widget>[
            ItemPage(pantryFilterId: _filterPantryId),
            PantryPage(),
            SettingsPage()
          ],
          onPageChanged: _onPageChanged,
        ),
        bottomNavigationBar:
            BottomNavigationBar(items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: 'Foods',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            label: 'Pantries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Settings',
          ),
        ], currentIndex: _pageIndex, onTap: _onBottomNavbarChanged),
      ),
      SpeedDialFAB(
          // onChanged: _onFabChanged,
          )
    ]);
  }
}

class SpeedDialFAB extends StatefulWidget {
  // final Function onChanged;

  // SpeedDialFAB({required this.onChanged});
  @override
  _SpeedDialFABState createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB>
    with TickerProviderStateMixin {
  bool _isOpened = false;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
  );

  late final _colorTweenBackgroundtoForeground = ColorTween(
          begin: Theme.of(context).primaryColor,
          end: Theme.of(context).primaryIconTheme.color)
      .animate(_controller);
  late final _colorTweenForegroundtoBackground = ColorTween(
          begin: Theme.of(context).primaryIconTheme.color,
          end: Theme.of(context).primaryColor)
      .animate(_controller);
  late final _tweenTransparenttoOpaque =
      ColorTween(begin: null, end: Colors.black.withOpacity(0.7))
          .animate(_controller);
  late final Animation<Offset> _offsetAnimation = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  ));

  void _toggle() {
    setState(() {
      _isOpened = !_isOpened;
    });

    if (_isOpened) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  Future<Widget?> _openDetail(Widget detailPage) async {
    _toggle();

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => detailPage),
    );

    // widget.onChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Visibility(
          child: GestureDetector(
              child: AnimatedModalBarrier(color: _tweenTransparenttoOpaque),
              behavior: HitTestBehavior.translucent,
              onDoubleTap: _toggle),
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          visible: _isOpened ? true : false,
        ),
        Positioned(
            bottom: 60,
            right: 25,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SlideTransition(
                    position: _offsetAnimation,
                    child: ScaleTransition(
                        scale: CurvedAnimation(
                            parent: _controller,
                            curve: Interval(0.5, 1, curve: Curves.easeOut)),
                        child: DefaultTextStyle(
                          style: TextStyle(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SpeedDialChild(
                                heroTag: 'FoodScan',
                                label: 'Scan Food',
                                child: Icon(Icons.qr_code_scanner_rounded),
                                onPressed: () async {
                                  await _openDetail(ScanPage());
                                },
                              ),
                              SpeedDialChild(
                                heroTag: 'Food',
                                label: 'Add Food',
                                child: Icon(Icons.fastfood),
                                onPressed: () async {
                                  await _openDetail(
                                      ItemDetailPage(isAdding: true));
                                },
                              ),
                              SpeedDialChild(
                                heroTag: 'Pantry',
                                label: 'Add Pantry',
                                child: Icon(Icons.kitchen),
                                onPressed: () async {
                                  await _openDetail(
                                      PantryDetailPage(isAdding: true));
                                },
                              )
                            ],
                          ),
                        ))),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return Transform.rotate(
                      angle: _controller.value * 0.25 * pi,
                      child: FloatingActionButton(
                        child: Icon(Icons.add),
                        tooltip: 'Add new',
                        onPressed: _toggle,
                        backgroundColor:
                            _colorTweenBackgroundtoForeground.value,
                        foregroundColor:
                            _colorTweenForegroundtoBackground.value,
                      ),
                    );
                  },
                )
              ],
            ))
      ],
    );
  }
}

class SpeedDialChild extends StatelessWidget {
  final String? label;
  final Widget? child;
  final Function()? onPressed;
  final String? heroTag;

  SpeedDialChild({this.label, this.child, this.onPressed, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(bottom: 25),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label == null ? '' : label!),
            Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 3.75, 0),
                child: FloatingActionButton(
                  heroTag: heroTag,
                  onPressed: onPressed,
                  child: child,
                  mini: true,
                ))
          ],
        ));
  }
}
// make an item location (can add new location, filter with that location and see items only from that location)
