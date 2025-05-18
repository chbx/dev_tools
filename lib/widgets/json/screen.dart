import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/search.dart';
import 'menu.dart';
import 'style.dart';
import 'viewer.dart';

class JsonViewerPage extends StatefulWidget {
  const JsonViewerPage({super.key});

  @override
  State<JsonViewerPage> createState() => _JsonViewerPageState();
}

class _JsonViewerPageState extends State<JsonViewerPage> {
  String _text = '';

  final JsonViewerController _jsonViewerController = JsonViewerController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'keyboard-shortcuts');
  final ValueNotifier<bool> _showSideNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _showSideNotifier.dispose();
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
        child: SearchSide(
          showSideNotifier: _showSideNotifier,
          side: Container(
            decoration: BoxDecoration(
              border: BoxBorder.fromLTRB(
                left: BorderSide(width: 0.1, color: Colors.grey),
              ),
            ),
            width: 400,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(top: 6, bottom: 6),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          width: 280,
                          height: 28,
                          child: SearchField(
                            controller: _jsonViewerController,
                            searchFieldEnabled: true,
                            supportsNavigation: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 2),
                      MenuIconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          _showSideNotifier.value = !_showSideNotifier.value;
                        },
                      ),
                      SizedBox(width: 6),
                    ],
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _jsonViewerController.searchMatches,
                    builder: (context, matches, child) {
                      return Container(
                        child: ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            JsonViewFindMatch findMatch = matches[index];
                            var buffer = StringBuffer('\$ > ');
                            for (final pathNode in findMatch.path) {
                              var treeData = pathNode.content;
                              buffer.write(treeData.name);
                              buffer.write(' > ');
                            }
                            return ListTile(title: Text(buffer.toString()));
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JsonViewerMenuBar(
                jsonViewerController: _jsonViewerController,
                onChanged: (value) {
                  setState(() => _text = value);
                },
                showSideNotifier: _showSideNotifier,
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
              sideWidth = math.max(width * 0.35, 320.0);
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
