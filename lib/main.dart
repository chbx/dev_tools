import 'dart:io';

import 'package:dev_tools/features/tabview/tabview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';
import 'package:macos_window_utils/window_manipulator.dart';

import 'features/json/json_viewer_page.dart';
import 'features/json/widgets/json_viewer_controller.dart';

void main() async {
  await init();
  runApp(const MyApp());
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) {
    await WindowManipulator.initialize();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // TODO 切换页面会有KEY泄漏
  final _bucket = PageStorageBucket();

  final _tabs = <MyAppTabData>[];
  int _selectedIndex = 0;
  int _createIndex = 0;
  bool _showSidebar = false;
  double _sidebarWidth = 300;

  final _sidebarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs.add(_createNewJsonViewerTab());
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _sidebar(),
          Expanded(
            child: TabView(
              selectedIndex: _selectedIndex,
              tabDataList: _tabs,
              onCreated: () {
                setState(() {
                  _tabs.add(_createNewJsonViewerTab());
                  _selectedIndex = _tabs.length - 1;
                });
              },
              onClosed: (index) {
                setState(() {
                  final oriSelectIndex = _selectedIndex;
                  final removedTab = _tabs.removeAt(index);
                  removedTab.jsonViewerController?.dispose();
                  if (_tabs.isEmpty) {
                    _tabs.add(_createNewJsonViewerTab());
                  }
                  if (index < oriSelectIndex) {
                    _selectedIndex = oriSelectIndex - 1;
                  }
                  if (_selectedIndex >= _tabs.length) {
                    _selectedIndex = _tabs.length - 1;
                  }
                });
              },
              onSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              hasSidebar: _showSidebar,
              tabPrefix: _showSidebar ? null : _sidebarIconButton(),
              content: Container(
                color: Colors.white,
                child: PageStorage(bucket: _bucket, child: _buildContent()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    if (!_showSidebar) {
      return SizedBox.shrink();
    }
    const resizeAreaWidth = 2.0;
    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Color(0xFFe0e0e0),
        border: BoxBorder.fromLTRB(
          right: BorderSide(width: 0.5, color: Colors.grey),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(left: 80.0),
            height: 38.0,
            child: MacosToolbarPassthroughScope(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        MacosToolbarPassthrough(child: _sidebarIconButton()),
                      ],
                    ),
                  ),
                  MacosToolbarPassthrough(
                    child: _sidebarResizeArea(resizeAreaWidth),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Scrollbar(
                  controller: _sidebarScrollController,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: ScrollConfiguration(
                      behavior: ScrollBehavior().copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        controller: _sidebarScrollController,
                        child: Column(
                          children: [
                            Material(
                              child: ListTile(
                                // leading: Icon(Icons.add),
                                contentPadding: EdgeInsets.only(left: 4.0),
                                visualDensity: VisualDensity(vertical: -4),
                                title: Text('Json Viewer'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('(New Tab)'),
                                    Icon(
                                      Icons.keyboard_arrow_right_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                dense: true,
                                onTap: () {
                                  setState(() {
                                    _tabs.add(_createNewJsonViewerTab());
                                    _selectedIndex = _tabs.length - 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Material(
                              child: ListTile(
                                // leading: Icon(Icons.add),
                                contentPadding: EdgeInsets.only(left: 4.0),
                                visualDensity: VisualDensity(vertical: -4),
                                title: Text('Timestamp'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('(Singleton)'),
                                    Icon(
                                      Icons.keyboard_arrow_right_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                dense: true,
                                onTap: () {
                                  setState(() {
                                    for (int i = 0; i < _tabs.length; i++) {
                                      final tab = _tabs[i];
                                      if (tab.tabType == TabType.timestamp) {
                                        _selectedIndex = i;
                                        return;
                                      }
                                    }
                                    _tabs.add(
                                      _createNewTab(
                                        tabName: 'Timestamp',
                                        tabType: TabType.timestamp,
                                      ),
                                    );
                                    _selectedIndex = _tabs.length - 1;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: _sidebarResizeArea(resizeAreaWidth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarResizeArea(double resizeAreaWidth) {
    return SizedBox(
      width: resizeAreaWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          supportedDevices: const {PointerDeviceKind.mouse},
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sidebarWidth += details.primaryDelta!;
            });
          },
          onHorizontalDragEnd: (details) {
            // setState(() {
            //   _sidebarWidth += ;
            // });
          },
          onHorizontalDragCancel: () => setState(() {}),
        ),
      ),
    );
  }

  Widget _sidebarIconButton() {
    return SizedBox.square(
      dimension: 26.0,
      child: Align(
        child: IconButton(
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
            ),
          ),
          onPressed: () {
            setState(() {
              _showSidebar = !_showSidebar;
            });
          },
          icon: Icon(CupertinoIcons.sidebar_left, size: 18),
        ),
      ),
    );
  }

  MyAppTabData _createNewJsonViewerTab() {
    return _createNewTab(
      tabName: "Json $_createIndex",
      tabType: TabType.jsonViewer,
      jsonViewerController: JsonViewerController(),
    );
  }

  MyAppTabData _createNewTab({
    String? tabName,
    required TabType tabType,
    JsonViewerController? jsonViewerController,
  }) {
    final data = MyAppTabData(
      id: _createIndex,
      tabName: tabName ?? 'Tab $_createIndex',
      tabType: tabType,
      jsonViewerController: jsonViewerController,
    );
    _createIndex++;
    return data;
  }

  Widget _buildContent() {
    final tabData = _tabs[_selectedIndex];

    final controller = tabData.jsonViewerController;
    Widget page;
    if (controller != null) {
      page = JsonViewerPage(
        jsonViewerController: controller,
        scrollIdV: 'I:${tabData.id},V',
        scrollIdH: 'I:${tabData.id},H',
      );
    } else {
      page = Text('Unsupported');
    }

    return page;
  }
}

class MyAppTabData extends TabData {
  MyAppTabData({
    required super.id,
    required super.tabName,
    required this.tabType,
    required this.jsonViewerController,
  });

  final TabType tabType;
  final JsonViewerController? jsonViewerController;
  double offsetV = 0.0;
  double offsetH = 0.0;
}

enum TabType { jsonViewer, timestamp }
