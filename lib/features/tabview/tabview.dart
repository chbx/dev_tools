import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';

class TabData {
  TabData({required this.id, required this.title});

  final int id;

  final String title;
}

class TabView extends StatefulWidget {
  const TabView({
    super.key,
    required this.selectedIndex,
    required this.tabDataList,
    required this.content,
    this.onClosed,
    this.onSelected,
    this.onCreated,
  });

  final List<TabData> tabDataList;
  final int selectedIndex;
  final Widget content;
  final void Function(int)? onClosed;
  final void Function(int)? onSelected;
  final void Function()? onCreated;

  @override
  State<TabView> createState() => _TabViewState();
}

class _TabViewState extends State<TabView> {
  final _hoverIndexNotifier = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _hoverIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _warpBar(
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildTabs(widget.tabDataList),
          ),
        ),
        Expanded(child: widget.content),
      ],
    );
  }

  List<Widget> _buildTabs(List<TabData> tabDataList) {
    final tabs = <Widget>[];
    for (int i = 0; i < tabDataList.length; i++) {
      final index = i;
      final tabData = tabDataList[i];
      tabs.add(
        _warpButton(
          TabButton(
            key: ValueKey(tabData.id),
            name: tabData.title,
            selected: index == widget.selectedIndex,
            onPressed: () {
              widget.onSelected?.call(index);
            },
            onClosed: () {
              widget.onClosed?.call(index);
            },
            selectColor: Color(0xFFf7f7f7),
            hoverColor: Color(0xFFc7c7c7),
            hoverIndexNotifier: _hoverIndexNotifier,
            index: index,
          ),
        ),
      );
      tabs.add(
        Align(
          child: SizedBox(
            height: 16.0,
            width: 1.0,
            child: ValueListenableBuilder(
              valueListenable: _hoverIndexNotifier,
              builder: (context, hoverIndex, child) {
                Color color;
                if ((hoverIndex != null &&
                        index >= hoverIndex - 1 &&
                        index <= hoverIndex) ||
                    (index >= widget.selectedIndex - 1 &&
                        index <= widget.selectedIndex)) {
                  color = Colors.transparent;
                } else {
                  color = Color.fromARGB(255, 208, 207, 207);
                }

                return DecoratedBox(decoration: BoxDecoration(color: color));
              },
            ),
          ),
        ),
      );
    }
    tabs.add(SizedBox(width: 4.0));
    tabs.add(
      Align(
        child: _warpButton(
          SizedBox.square(
            dimension: 24.0,
            child: IconButton(
              padding: EdgeInsets.all(0.0),
              onPressed: () {
                widget.onCreated?.call();
              },
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              icon: Icon(Icons.add, size: 18),
            ),
          ),
        ),
      ),
    );

    return tabs;
  }

  Widget _warpBar(Widget widget) {
    if (Platform.isMacOS) {
      const tabBarMaxHeight = 38.0;
      const tabBarPaddingTop = 4.0;
      const tabBarInnerHeight = tabBarMaxHeight - tabBarPaddingTop;
      return Container(
        padding: EdgeInsets.only(left: 80.0, top: tabBarPaddingTop),
        height: tabBarMaxHeight,
        color: Color(0xFFe3e3e3),
        child: MacosToolbarPassthroughScope(child: widget),
      );
    } else {
      return widget;
    }
  }

  Widget _warpButton(Widget widget) {
    if (Platform.isMacOS) {
      return MacosToolbarPassthrough(enableDebugLayers: false, child: widget);
    } else {
      return widget;
    }
  }
}

class TabButton extends StatefulWidget {
  const TabButton({
    super.key,
    required this.name,
    required this.selected,
    required this.onPressed,
    required this.onClosed,
    required this.selectColor,
    required this.hoverColor,
    required this.index,
    required this.hoverIndexNotifier,
  });

  @override
  State<TabButton> createState() => _TabButtonState();

  final String name;
  final bool selected;
  final VoidCallback? onPressed;
  final VoidCallback? onClosed;
  final Color selectColor;
  final Color hoverColor;
  final int index;
  final ValueNotifier<int?> hoverIndexNotifier;
}

class _TabButtonState extends State<TabButton> {
  final Set<WidgetState> _states = {};

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    if (widget.selected) {
      bgColor = widget.selectColor;
    } else if (WidgetState.hovered.isSatisfiedBy(_states)) {
      bgColor = widget.hoverColor;
    }

    BorderRadius? borderRadius;
    if (widget.selected || WidgetState.hovered.isSatisfiedBy(_states)) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
      );
    }

    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        onEnter: (event) {
          setState(() {
            widget.hoverIndexNotifier.value = widget.index;
            _states.add(WidgetState.hovered);
          });
        },
        onExit: (event) {
          setState(() {
            widget.hoverIndexNotifier.value = null;
            _states.remove(WidgetState.hovered);
          });
        },
        child: AnimatedContainer(
          duration:
              widget.selected ? Duration.zero : Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
          ),

          child: Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: 80),
                child: Text(widget.name),
              ),
              SizedBox.square(
                dimension: 18,
                child: IconButton(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                  padding: const EdgeInsets.all(0.0),
                  onPressed: widget.onClosed,
                  icon: const Icon(Icons.close, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
