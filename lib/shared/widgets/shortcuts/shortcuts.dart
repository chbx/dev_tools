import 'package:flutter/widgets.dart';

class ShortcutsConfiguration {
  const ShortcutsConfiguration({required this.shortcuts, required this.actions})
    : assert(shortcuts.length == actions.length);

  factory ShortcutsConfiguration.empty() {
    return ShortcutsConfiguration(shortcuts: {}, actions: {});
  }

  final Map<ShortcutActivator, Intent> shortcuts;
  final Map<Type, Action<Intent>> actions;

  bool get isEmpty => shortcuts.isEmpty && actions.isEmpty;
}

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({
    super.key,
    required this.keyboardShortcuts,
    required this.child,
  });

  final ShortcutsConfiguration keyboardShortcuts;
  final Widget child;

  @override
  KeyboardShortcutsState createState() => KeyboardShortcutsState();
}

class KeyboardShortcutsState extends State<KeyboardShortcuts> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'keyboard-shortcuts');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.keyboardShortcuts.isEmpty) {
      return widget.child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: FocusableActionDetector(
        shortcuts: widget.keyboardShortcuts.shortcuts,
        actions: widget.keyboardShortcuts.actions,
        autofocus: true,
        focusNode: _focusNode,
        child: widget.child,
      ),
    );
  }
}
