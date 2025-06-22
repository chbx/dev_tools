import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/shortcuts/key_sets.dart';
import '../../shared/widgets/shortcuts/shortcuts.dart';
import 'widgets/json_viewer.dart';
import 'widgets/json_viewer_controller.dart';
import 'widgets/json_viewer_theme.dart';

class JsonViewerPage extends StatelessWidget {
  const JsonViewerPage({
    super.key,
    required this.jsonViewerController,
    required this.scrollIdH,
    required this.scrollIdV,
  });

  final JsonViewerController jsonViewerController;

  final String scrollIdH;
  final String scrollIdV;

  @override
  Widget build(BuildContext context) {
    final double menuBarHeight = 28.0;
    final media = MediaQuery.of(context);
    return KeyboardShortcuts(
      keyboardShortcuts: buildKeyboardShortcuts(jsonViewerController),
      child: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: menuBarHeight),
            ),
            child: JsonViewer(
              themeData: JsonViewerThemeData(
                color: defaultColorThemeData,
                prefixWidth: 28.0,
                indentWidth: 24.0,
                fontFamily: 'Menlo',
                fontSize: 14.0,
                spaceAfterIcon: 4,
              ),
              controller: jsonViewerController,
              scrollIdH: scrollIdH,
              scrollIdV: scrollIdV,
            ),
          ),
          Positioned(
            left: 0.0,
            right: 0.0,
            top: 0.0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: MenuBar(
                  jsonViewerController: jsonViewerController,
                  onChanged: (value) {
                    jsonViewerController.text = value;
                  },
                  height: menuBarHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ShortcutsConfiguration buildKeyboardShortcuts(
    JsonViewerController controller,
  ) {
    final shortcuts = <LogicalKeySet, Intent>{
      searchInFileKeySet: SearchInFileIntent(controller),
    };
    final actions = <Type, Action<Intent>>{
      SearchInFileIntent: SearchInFileAction(),
    };
    return ShortcutsConfiguration(shortcuts: shortcuts, actions: actions);
  }
}

class SearchInFileIntent extends Intent {
  const SearchInFileIntent(this._controller);

  final JsonViewerController _controller;
}

class SearchInFileAction extends Action<SearchInFileIntent> {
  @override
  void invoke(SearchInFileIntent intent) {
    intent._controller.showOrFocusSearchField();
  }
}

class MenuBar extends StatelessWidget {
  const MenuBar({
    super.key,
    required this.jsonViewerController,
    this.onChanged,
    required this.height,
  });

  final JsonViewerController jsonViewerController;

  final ValueChanged<String>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    const spacing = 2.0;
    return Container(
      height: height,
      padding: EdgeInsets.only(top: 2, bottom: 2),
      color: const Color(0xAAf7f7f7),
      child: Row(
        children: [
          SizedBox(width: 10),
          IconMenuButton(
            onPressed: () async {
              final text = await Clipboard.getData('text/plain');
              onChanged?.call(text?.text ?? '');
            },
            tooltip: 'Paste',
            icon: Icon(Icons.paste_rounded),
          ),
          SizedBox(width: spacing),
          IconMenuButton(
            onPressed: () async {
              final text = jsonViewerController.getTextContent();
              if (text != null) {
                await Clipboard.setData(ClipboardData(text: text));
              }
            },
            tooltip: 'Copy',
            icon: Icon(Icons.copy_rounded),
          ),
          SizedBox(width: spacing),
          IconMenuButton(
            onPressed: () {
              onChanged?.call('');
            },
            tooltip: 'Clear',
            icon: Icon(Icons.clear_rounded),
          ),
          SizedBox(width: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(width: 1, color: Colors.grey[400]!),
              ),
            ),
            child: SizedBox(height: 14),
          ),
          SizedBox(width: 4),
          IconMenuButton(
            onPressed: () {
              jsonViewerController.expandAll();
            },
            tooltip: 'Expand All',
            icon: Icon(Icons.unfold_more_rounded),
          ),
          SizedBox(width: spacing),
          IconMenuButton(
            onPressed: () {
              jsonViewerController.collapseAll();
            },
            tooltip: 'Collapse All',
            icon: Icon(Icons.unfold_less_rounded),
          ),
        ],
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, this.onPressed, required this.child});

  final VoidCallback? onPressed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 22;
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

class IconMenuButton extends StatelessWidget {
  const IconMenuButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback? onPressed;

  final Widget icon;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      waitDuration: Duration(milliseconds: 500),
      message: tooltip,
      padding: const EdgeInsets.all(8.0),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        style: IconButton.styleFrom(
          iconSize: 14,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}
