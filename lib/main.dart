import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:math';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(MyApp());
}

const numberOfRows = 500;
const numberOfItemsPerRow = 20;
const minItemHeight = 200.0;
const maxItemHeight = 200.0;
const scrollDuration = Duration(milliseconds: 450);
const animationDuration = Duration(milliseconds: 450);
const textStyle =
    TextStyle(backgroundColor: Colors.black45, color: Colors.white);
const textStyleActive =
    TextStyle(backgroundColor: Colors.red, color: Colors.black);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ScrollablePositionedListPage(),
    );
  }
}

class ScrollablePositionedListPage extends StatefulWidget {
  const ScrollablePositionedListPage({Key key}) : super(key: key);

  @override
  _ScrollablePositionedListPageState createState() =>
      _ScrollablePositionedListPageState();
}

class _ScrollablePositionedListPageState
    extends State<ScrollablePositionedListPage> {
  final ItemScrollController itemScrollController = ItemScrollController();

  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  List<double> itemHeights;
  List<Color> itemColors;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    final heightGenerator = Random(328902348);
    final colorGenerator = Random(42490823);
    itemHeights = List<double>.generate(
        numberOfRows,
        (int _) =>
            heightGenerator.nextDouble() * (maxItemHeight - minItemHeight) +
            minItemHeight);
    itemColors = List<Color>.generate(
        numberOfRows,
        (int _) =>
            Color(colorGenerator.nextInt(pow(2, 32) - 1)).withOpacity(1));
  }

  @override
  Widget build(BuildContext context) => RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (value) {
        var data = value.data;
        print(data.logicalKey.debugName);
        if ((value is RawKeyDownEvent || value is RawKeyEventDataLinux) &&
            (data.logicalKey.debugName == 'Arrow Up' ||
                data.logicalKey.keyId == 265)) {
          print('Arrow Up');
          if (_current > 0) {
            setState(() {
              _current--;
            });
            scrollTo(_current);
          }
        }
        if ((value is RawKeyDownEvent || value is RawKeyEventDataLinux) &&
            (data.logicalKey.debugName == 'Arrow Down' ||
                data.logicalKey.keyId == 264)) {
          print('Arrow Down');
          if (_current <= numberOfRows) {
            setState(() {
              _current++;
            });
            scrollTo(_current);
          }
        }
      },
      child: Material(
          child: ScrollablePositionedList.builder(
        itemCount: numberOfRows,
        itemBuilder: (context, index) => item(index),
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        scrollDirection: Axis.vertical,
      )));

  void scrollTo(int index) => itemScrollController.scrollTo(
      index: index, duration: scrollDuration, curve: Curves.easeInOutCubic);

  Widget listBuild(int i) {
    int itemCount = numberOfItemsPerRow;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.all(5.0),
          width: 152,
          decoration: BoxDecoration(
            color: Colors.white54,
            border: Border.all(
              color: itemColors[i],
              width: 2.0,
            ),
          ),
          child: Image.network('http://picsum.photos/150/150?id=1$i$index'),
        );
      },
    );
  }

  /// Generate item number [i].
  Widget item(int i) {
    return SizedBox(
      height: itemHeights[i],
      child: AnimatedContainer(
        duration: animationDuration,
        height: itemHeights[i],
        margin: const EdgeInsets.all(10.0),
        padding: const EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: i == _current
              ? itemColors[i].withOpacity(0.5)
              : itemColors[i].withOpacity(0.1),
          border: i == _current
              ? Border.all(
                  color: itemColors[i],
                  width: 4.0,
                )
              : Border.all(
                  color: Colors.transparent,
                  width: 4.0,
                ),
        ),
        // child: listBuild(i),
        child: Stack(children: [
          Container(
            child: listBuild(i),
          ),
          Center(
            child: i == _current
                ? Text(
                    'Active Group ${i + 1}',
                    style: textStyleActive,
                  )
                : Text(
                    'Group ${i + 1}',
                    style: textStyle,
                  ),
          )
        ]),
        // child: Stack(
        //   children: [
        //     Container(
        //       height: double.infinity,
        //       width: double.infinity,
        //       child: Image.network('https://picsum.photos/500/200?id=${i + 1}'),
        //     ),
        //     Center(
        //       child: i == _current
        //           ? Text('Active Item ${i + 1}')
        //           : Text('Item ${i + 1}'),
        //     )
        //   ],
        // ),
      ),
    );
  }
}
