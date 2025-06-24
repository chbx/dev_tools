import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';

const double _redYellowGreenWidth = 80.0;

class MacosDesktopStyle {
  MacosDesktopStyle({
    required this.toolbarHeight,
    required this.toolbarBackgroundColor,
    required this.sidebarBackgroundColor,
  });

  final double toolbarHeight;
  final Color toolbarBackgroundColor;
  final Color sidebarBackgroundColor;
}

class MacosDesktopScaffold extends StatefulWidget {
  const MacosDesktopScaffold({
    super.key,
    required this.style,
    required this.sidebarBuilder,
    required this.toolbar,
    required this.content,
  });

  final MacosDesktopStyle style;

  final Widget Function() sidebarBuilder;

  final Widget toolbar;

  final Widget content;

  @override
  State<MacosDesktopScaffold> createState() => _MacosDesktopScaffoldState();
}

class _MacosDesktopScaffoldState extends State<MacosDesktopScaffold>
    with SingleTickerProviderStateMixin {
  bool _showSidebar = false;
  final _sidebarWidthNotifier = ValueNotifier<double>(300);
  late final AnimationController _sidebarShowController;

  @override
  void initState() {
    super.initState();
    _sidebarShowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    _sidebarShowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _showSidebar ? _sidebar() : const SizedBox.shrink(),
              Expanded(
                child: widget.content,
                // Container(
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     boxShadow: [
                //       BoxShadow(
                //         offset: Offset(-2, 0),
                //         blurRadius: 0,
                //         // spreadRadius: 2,
                //       ),
                //     ],
                //   ),
                //  child:
                // ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return MacosToolbarPassthroughScope(
      child: Stack(
        children: [
          SizedBox(
            height: widget.style.toolbarHeight,
            child: Row(
              children: [
                _sidebarBackground(),
                Expanded(
                  child: Container(color: widget.style.toolbarBackgroundColor),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: _sidebarWidthNotifier,
                  builder: (context, sidebarWidth, child) {
                    return SizedBox(
                      width: _showSidebar ? sidebarWidth : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: _redYellowGreenWidth,
                          ),
                          child: MacosToolbarPassthrough(
                            child: _sidebarIconButton(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4.0),
                widget.toolbar,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarBackground() {
    return _showSidebar
        ? Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: _sidebarWidthNotifier,
              builder: (context, sidebarWidth, child) {
                return Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: widget.style.sidebarBackgroundColor,
                    border: BoxBorder.fromLTRB(
                      right: BorderSide(width: 0.5, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 0.0,
              bottom: 0.0,
              right: 0.0,
              child: MacosToolbarPassthrough(child: _sidebarResizeArea()),
            ),
          ],
        )
        : const SizedBox.shrink();
  }

  Widget _sidebar() {
    return ValueListenableBuilder(
      valueListenable: _sidebarWidthNotifier,
      builder: (context, sidebarWidth, child) {
        return SizedBox(
          width: sidebarWidth,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.style.sidebarBackgroundColor,
                    border: BoxBorder.fromLTRB(
                      right: BorderSide(width: 0.5, color: Colors.grey),
                    ),
                  ),
                  child: widget.sidebarBuilder.call(),
                ),
              ),
              Positioned(
                top: 0.0,
                bottom: 0.0,
                right: 0.0,
                child: _sidebarResizeArea(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sidebarResizeArea() {
    const resizeAreaWidth = 2.0;
    return SizedBox(
      width: resizeAreaWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          supportedDevices: const {PointerDeviceKind.mouse},
          onHorizontalDragUpdate: (details) {
            _sidebarWidthNotifier.value += details.primaryDelta!;
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
}
