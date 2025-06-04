import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/shortcuts/key_sets.dart';
import '../../shared/widgets/shortcuts/shortcuts.dart';
import 'widgets/json_viewer.dart';
import 'widgets/json_viewer_controller.dart';
import 'widgets/json_viewer_theme.dart';

class JsonViewerPage extends StatelessWidget {
  const JsonViewerPage({super.key, required this.jsonViewerController});

  final JsonViewerController jsonViewerController;

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcuts(
      keyboardShortcuts: buildKeyboardShortcuts(jsonViewerController),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuBar(
            jsonViewerController: jsonViewerController,
            onChanged: (value) {
              jsonViewerController.text = value;
            },
          ),
          Expanded(
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
              final text = await Clipboard.getData('text/plain');
              onChanged?.call(text?.text ?? '');
            },
            child: Text('Paste'),
          ),
          SizedBox(width: 6),
          MenuButton(
            onPressed: () async {
              final text = jsonViewerController.getTextContent();
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
