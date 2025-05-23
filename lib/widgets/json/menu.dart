import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/search.dart';
import 'viewer.dart';

class JsonViewerMenuBar extends StatelessWidget {
  const JsonViewerMenuBar({
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
          _MenuButton(
            onPressed: () async {
              var text = await Clipboard.getData('text/plain');
              onChanged?.call(text?.text ?? '');
            },
            child: Text('Paste'),
          ),
          SizedBox(width: 6),
          _MenuButton(
            onPressed: () async {
              var text = jsonViewerController.getTextContent();
              if (text != null) {
                await Clipboard.setData(ClipboardData(text: text));
              }
            },
            child: Text('Copy'),
          ),
          SizedBox(width: 6),
          _MenuButton(
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
          _MenuButton(
            onPressed: () {
              jsonViewerController.expandAll();
            },
            child: Text('Expand'),
          ),
          SizedBox(width: 6),
          _MenuButton(
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({super.key, this.onPressed, required this.child});

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
