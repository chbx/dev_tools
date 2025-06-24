import 'dart:io';

import 'package:dev_tools/features/scaffold/macos_scaffold.dart';
import 'package:dev_tools/features/tabview/tabview.dart';
import 'package:flutter/material.dart';
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
      home: Scaffold(body: const MyHomePage()),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class TabViewData {
  TabViewData({required this.tabs, required this.selectedIndex});

  final List<MyAppTabData> tabs;

  final int selectedIndex;
}

class _MyHomePageState extends State<MyHomePage> {
  // TODO 切换页面会有KEY泄漏
  final _bucket = PageStorageBucket();

  late final ValueNotifier<TabViewData> _tabViewDataNotifier;
  int _createIndex = 0;

  final _sidebarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabViewDataNotifier = ValueNotifier(
      TabViewData(tabs: [_createNewJsonViewerTab()], selectedIndex: 0),
    );
  }

  @override
  void dispose() {
    _tabViewDataNotifier.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MacosDesktopScaffold(
        style: MacosDesktopStyle(
          toolbarHeight: 38.0,
          toolbarBackgroundColor: Color(0xFFe3e3e3),
          sidebarBackgroundColor: Color(0xFFe0e0e0),
        ),
        sidebarBuilder: _sidebar,
        toolbar: _toolbar(),
        content: Container(
          color: Colors.white,
          child: PageStorage(bucket: _bucket, child: _buildContent()),
        ),
      ),
    );
  }

  Widget _toolbar() {
    return ValueListenableBuilder(
      valueListenable: _tabViewDataNotifier,
      builder: (context, tabViewData, child) {
        return TabView(
          selectedIndex: tabViewData.selectedIndex,
          tabData: tabViewData.tabs,
          onCreated: () {
            final tabs = _tabViewDataNotifier.value.tabs;
            tabs.add(_createNewJsonViewerTab());
            _tabViewDataNotifier.value = TabViewData(
              tabs: tabs,
              selectedIndex: tabs.length - 1,
            );
          },
          onClosed: (index) {
            final tabViewData = _tabViewDataNotifier.value;
            final tabs = tabViewData.tabs;
            final oriSelectIndex = tabViewData.selectedIndex;

            final removedTab = tabs.removeAt(index);
            removedTab.jsonViewerController?.dispose();
            if (tabs.isEmpty) {
              tabs.add(_createNewJsonViewerTab());
            }
            int selectIndex = oriSelectIndex;
            if (index < oriSelectIndex) {
              selectIndex = oriSelectIndex - 1;
            }
            if (selectIndex >= tabs.length) {
              selectIndex = tabs.length - 1;
            }
            _tabViewDataNotifier.value = TabViewData(
              tabs: tabs,
              selectedIndex: selectIndex,
            );
          },
          onSelected: (index) {
            final tabViewData = _tabViewDataNotifier.value;
            _tabViewDataNotifier.value = TabViewData(
              tabs: tabViewData.tabs,
              selectedIndex: index,
            );
          },
        );
      },
    );
  }

  Widget _sidebar() {
    return Scrollbar(
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
                        Icon(Icons.keyboard_arrow_right_rounded, size: 18),
                      ],
                    ),
                    dense: true,
                    onTap: () {
                      final tabs = _tabViewDataNotifier.value.tabs;
                      tabs.add(_createNewJsonViewerTab());
                      _tabViewDataNotifier.value = TabViewData(
                        tabs: tabs,
                        selectedIndex: tabs.length - 1,
                      );
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
                        Icon(Icons.keyboard_arrow_right_rounded, size: 18),
                      ],
                    ),
                    dense: true,
                    onTap: () {
                      final tabViewData = _tabViewDataNotifier.value;
                      final tabs = tabViewData.tabs;

                      int? selectedIndex;
                      for (int i = 0; i < tabs.length; i++) {
                        final tab = tabs[i];
                        if (tab.tabType == TabType.timestamp) {
                          selectedIndex = i;
                          break;
                        }
                      }
                      if (selectedIndex == null) {
                        tabs.add(
                          _createNewTab(
                            tabName: 'Timestamp',
                            tabType: TabType.timestamp,
                          ),
                        );
                        selectedIndex = tabs.length - 1;
                      }

                      _tabViewDataNotifier.value = TabViewData(
                        tabs: tabs,
                        selectedIndex: tabs.length - 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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
    return ValueListenableBuilder(
      valueListenable: _tabViewDataNotifier,
      builder: (context, tabViewData, child) {
        final tabData = tabViewData.tabs[tabViewData.selectedIndex];

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
      },
    );
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
