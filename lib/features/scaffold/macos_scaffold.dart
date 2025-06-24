import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';

const double _redYellowGreenWidth = 80.0;
const double _sidebarButtonSize = 26.0;
const double _minSidebarWidth = 180;
const double _resizeAreaWidth = 3.0;

typedef _SidebarAwareBuilder =
    Widget Function(
      double sidebarWidth,
      double animatedSidebarWidth,
      Widget? child,
    );

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
  final _sidebarWidthNotifier = ValueNotifier<double>(240);
  double? _sidebarWidthBeforeResizeCache;
  double _sidebarWidthResizeDelta = 0;

  late final AnimationController _sidebarShowController;
  late final CurvedAnimation _sidebarShowAnimation;

  @override
  void initState() {
    super.initState();
    _sidebarShowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _sidebarShowAnimation = CurvedAnimation(
      parent: _sidebarShowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _sidebarWidthNotifier.dispose();
    _sidebarShowAnimation.dispose();
    _sidebarShowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // BACKGROUND:
    //   LEFT  (toolbar & sidebar same color)
    //   RIGHT:  (boxShadow if sidebar exists)
    //     toolbar
    //     content
    // FG:
    //   TOP: toolbar (animated & adjustWidthArea & toolbarContent)
    //   BOTTOM: (stack)
    //     LEFT: sidebar (stack: sidebar & adjustWidthArea)
    //     RIGHT: content

    return Stack(children: [_background(), _foreground()]);
  }

  Widget _background() {
    return _sidebarAware(
      builder: (_, animatedSidebarWidth, child) {
        // add boxShadow if sidebar exists
        Widget rightContent = child!;
        if (animatedSidebarWidth > 0) {
          rightContent = DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset.zero,
                  blurRadius: 0.5,
                ),
              ],
            ),
            child: rightContent,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT (sidebar cross toolbar)
            SizedBox(
              width: animatedSidebarWidth,
              child: ColoredBox(color: widget.style.sidebarBackgroundColor),
            ),
            // RIGHT (toolbar & content)
            Expanded(child: rightContent),
          ],
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.style.toolbarHeight,
            child: ColoredBox(color: widget.style.toolbarBackgroundColor),
          ),
          // Expanded(child: ColoredBox(color: Colors.white)),
          Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _foreground() {
    return Column(children: [_toolbar(), Expanded(child: _body())]);
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.only(left: _redYellowGreenWidth),
      child: SizedBox(
        height: widget.style.toolbarHeight,
        child: MacosToolbarPassthroughScope(
          child: Row(
            children: [
              MacosToolbarPassthrough(child: _sidebarIconButton()),
              _sidebarAware(
                builder: (sidebarWidth, animatedSidebarWidth, _) {
                  final width =
                      animatedSidebarWidth -
                      _redYellowGreenWidth -
                      _sidebarButtonSize;
                  if (width <= 0) {
                    return SizedBox.shrink();
                  }
                  final resize =
                      _sidebarShowController.isCompleted &&
                      width > _resizeAreaWidth;
                  return SizedBox(
                    width: width,
                    height: widget.style.toolbarHeight,
                    child:
                        resize
                            ? Align(
                              alignment: Alignment.centerRight,
                              child: MacosToolbarPassthrough(
                                child: _sidebarResizeArea(),
                              ),
                            )
                            : null,
                  );
                },
              ),
              const SizedBox(width: 4.0),
              Expanded(child: widget.toolbar),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return _sidebarAware(
      builder: (sidebarWidth, animatedSidebarWidth, child) {
        Widget? sidebar;
        if (animatedSidebarWidth > 0) {
          Widget current = child!;
          if (_sidebarShowController.isCompleted) {
            current = Stack(
              children: [
                current,
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: _sidebarResizeArea(),
                ),
              ],
            );
          }
          sidebar = Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: SizedBox(width: sidebarWidth, child: current),
          );
        }

        return Stack(
          children: [
            if (sidebar != null) sidebar,
            Positioned(
              top: 0,
              bottom: 0,
              left: animatedSidebarWidth,
              right: 0,
              child: ColoredBox(color: Colors.white, child: widget.content),
            ),
          ],
        );
      },
      child: widget.sidebarBuilder.call(),
    );
  }

  Widget _sidebarAware({required _SidebarAwareBuilder builder, Widget? child}) {
    return ValueListenableBuilder(
      valueListenable: _sidebarWidthNotifier,
      builder: (context, sidebarWidth, child_) {
        return AnimatedBuilder(
          animation: _sidebarShowController,
          builder: (context, child_) {
            final animatedSidebarWidth = Tween(
              begin: 0.0,
              end: sidebarWidth,
            ).evaluate(_sidebarShowAnimation);
            return builder.call(sidebarWidth, animatedSidebarWidth, child);
          },
        );
      },
    );
  }

  Widget _sidebarResizeArea() {
    return SizedBox(
      width: _resizeAreaWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          supportedDevices: const {PointerDeviceKind.mouse},
          onHorizontalDragUpdate: (details) {
            _sidebarWidthBeforeResizeCache ??= _sidebarWidthNotifier.value;
            _sidebarWidthResizeDelta += details.primaryDelta!;
            final newWidth =
                (_sidebarWidthBeforeResizeCache ?? 0) +
                _sidebarWidthResizeDelta;
            if (newWidth > _minSidebarWidth) {
              _sidebarWidthNotifier.value = newWidth;
            }
          },
          onHorizontalDragEnd: (details) {
            _sidebarWidthResizeDelta = 0;
            _sidebarWidthBeforeResizeCache = null;
          },
          // onHorizontalDragCancel: () => setState(() {}),
        ),
      ),
    );
  }

  Widget _sidebarIconButton() {
    return SizedBox.square(
      dimension: _sidebarButtonSize,
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
            _sidebarShowController.toggle();
          },
          icon: Icon(CupertinoIcons.sidebar_left, size: 18),
        ),
      ),
    );
  }
}
