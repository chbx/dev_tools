import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/json/json_viewer.dart';
import 'widgets/search.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(color: Colors.white, child: JsonViewerPage()),
    );
  }
}

class JsonViewerPage extends StatefulWidget {
  const JsonViewerPage({super.key});

  @override
  State<JsonViewerPage> createState() => _JsonViewerPageState();
}

class _JsonViewerPageState extends State<JsonViewerPage> {
  String _text = '';

  final JsonViewerController _jsonViewerController = JsonViewerController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'keyboard-shortcuts');

  @override
  void dispose() {
    _jsonViewerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: FocusableActionDetector(
        shortcuts: {
          // LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
          SingleActivator(
            LogicalKeyboardKey.keyF,
            control: !Platform.isMacOS,
            meta: Platform.isMacOS,
          ): SearchInFileIntent(_jsonViewerController),
        },
        actions: {SearchInFileIntent: SearchInFileAction()},
        focusNode: _focusNode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MenuBar(
              jsonViewerController: _jsonViewerController,
              onChanged: (value) {
                setState(() => _text = value);
              },
            ),
            Expanded(
              child: JsonViewer(
                text: _text,
                theme: defaultTheme,
                controller: _jsonViewerController,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchInFileIntent extends Intent {
  const SearchInFileIntent(this._controller);

  final JsonViewerController _controller;
}

class SearchInFileAction extends Action<SearchInFileIntent> {
  @override
  void invoke(SearchInFileIntent intent) {
    intent._controller.toggleSearch();
  }
}

class MenuBar extends StatelessWidget {
  const MenuBar({
    super.key,
    required this.jsonViewerController,
    this.onChanged,
  });

  final JsonViewerController jsonViewerController;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 6, bottom: 6),
      color: Colors.grey[100],
      child: Row(
        children: [
          SizedBox(width: 10),
          MenuButton(
            onPressed: () async {
              var text = await Clipboard.getData('text/plain');
              onChanged?.call(text?.text ?? '');
            },
            child: Text('Paste'),
          ),
          SizedBox(width: 6),
          MenuButton(
            onPressed: () async {
              var text = jsonViewerController.getTextContent();
              if (text != null) {
                await Clipboard.setData(ClipboardData(text: text));
              }
            },
            child: Text('Copy'),
          ),
          SizedBox(width: 6),
          MenuButton(
            onPressed: () {
              onChanged?.call('');
            },
            child: Text('Clear'),
          ),

          SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(width: 1, color: Colors.grey[400]!),
              ),
            ),
            child: SizedBox(height: 20),
          ),
          SizedBox(width: 8),
          MenuButton(
            onPressed: () {
              jsonViewerController.expandAll();
            },
            child: Text('Expand'),
          ),
          SizedBox(width: 6),
          MenuButton(
            onPressed: () {
              jsonViewerController.collapseAll();
            },
            child: Text('Collapse'),
          ),
          SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(width: 1, color: Colors.grey[400]!),
              ),
            ),
            child: SizedBox(height: 20),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 320,
            height: 28,
            child: SearchField(
              controller: jsonViewerController,
              searchFieldEnabled: true,
              supportsNavigation: true,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchSide extends StatelessWidget {
  const SearchSide({
    super.key,
    required this.showSideNotifier,
    required this.content,
    required this.side,
  });

  final ValueListenable<bool> showSideNotifier;
  final Widget content;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: showSideNotifier,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            var width = constraints.maxWidth;
            var sideWidth = 0.0;
            if (showSideNotifier.value) {
              sideWidth = min(width * 0.35, 400.0);
            }
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth - sideWidth,
                  height: constraints.maxHeight,
                  child: content,
                ),
                if (showSideNotifier.value)
                  Container(
                    width: sideWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey)),
                    ),
                    child: side,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, this.onPressed, required this.child});

  final VoidCallback? onPressed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 28;
    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: 13),
          child: child,
        ),
      ),
    );
  }
}

class MenuIconButton extends StatelessWidget {
  const MenuIconButton({super.key, this.onPressed, required this.icon});

  final VoidCallback? onPressed;

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          iconSize: 18,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}
