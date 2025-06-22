import 'dart:io';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

  @override
  void initState() {
    super.initState();
    _tabs.add(_createNewTab());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabView(
        selectedIndex: _selectedIndex,
        tabDataList: _tabs,
        onCreated: () {
          setState(() {
            _tabs.add(_createNewTab());
            _selectedIndex = _tabs.length - 1;
          });
        },
        onClosed: (index) {
          setState(() {
            final oriSelectIndex = _selectedIndex;
            final removedTab = _tabs.removeAt(index);
            removedTab.jsonViewerController.dispose();
            if (_tabs.isEmpty) {
              _tabs.add(_createNewTab());
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
        content: Container(
          color: Colors.white,
          child: PageStorage(bucket: _bucket, child: _buildContent()),
        ),
      ),
    );
  }

  MyAppTabData _createNewTab() {
    final data = MyAppTabData(
      id: _createIndex,
      title: "Json $_createIndex",
      jsonViewerController: JsonViewerController(),
    );
    _createIndex++;
    return data;
  }

  Widget _buildContent() {
    final tabData = _tabs[_selectedIndex];
    final controller = tabData.jsonViewerController;
    final page = JsonViewerPage(
      jsonViewerController: controller,
      scrollIdV: 'I:${tabData.id},V',
      scrollIdH: 'I:${tabData.id},H',
    );
    return page;
  }
}

class MyAppTabData extends TabData {
  MyAppTabData({
    required super.id,
    required super.title,
    required this.jsonViewerController,
  });

  final JsonViewerController jsonViewerController;
  double offsetV = 0.0;
  double offsetH = 0.0;
}
