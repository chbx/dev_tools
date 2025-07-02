import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';

const double _redYellowGreenWidth = 80.0;
const double _sidebarButtonSize = 26.0;
const double _minSidebarWidth = 180;
const double _resizeAreaWidth = 3.0;

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
      duration: Duration(milliseconds: 2000),
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

    return Stack(
      children: [
        // _Background(
        //   style: widget.style,
        //   sidebarWidth: _sidebarWidthNotifier,
        //   sidebarAnimation: _sidebarShowAnimation,
        // ),
        Stack(
          children: [
            _Body(
              sidebarWidth: _sidebarWidthNotifier,
              sidebarAnimation: _sidebarShowAnimation,
              style: widget.style,
              sidebarBuilder: widget.sidebarBuilder,
              resizeArea: _sidebarResizeArea(),
              content: widget.content,
            ),
            Positioned(
              left: 0,
              right: 0,
              child: _Toolbar(
                style: widget.style,
                sidebarWidth: _sidebarWidthNotifier,
                sidebarAnimation: _sidebarShowAnimation,
                customToobar: widget.toolbar,
                onSidebarButtonPressed: () {
                  _sidebarShowController.toggle();
                },
                resizeArea: _sidebarResizeArea(),
              ),
            ),
          ],
        ),
      ],
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
}

typedef _SidebarAwareBuilder =
    Widget Function(
      double sidebarWidth,
      double animatedSidebarWidth,
      Widget? child,
    );

mixin _SidebarWidthBase {
  ValueListenable<double> get sidebarWidth;
  CurvedAnimation get sidebarAnimation;

  Widget sidebarWidthBuilder({
    required _SidebarAwareBuilder builder,
    Widget? child,
  }) {
    return ValueListenableBuilder(
      valueListenable: sidebarWidth,
      builder: (context, sidebarWidth, child_) {
        return AnimatedBuilder(
          animation: sidebarAnimation,
          builder: (context, child_) {
            final animatedSidebarWidth = Tween(
              begin: 0.0,
              end: sidebarWidth,
            ).evaluate(sidebarAnimation);
            return builder.call(sidebarWidth, animatedSidebarWidth, child);
          },
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget with _SidebarWidthBase {
  const _Toolbar({
    super.key,
    required this.sidebarWidth,
    required this.sidebarAnimation,
    required this.style,
    required this.customToobar,
    required this.onSidebarButtonPressed,
    required this.resizeArea,
  });

  @override
  final ValueListenable<double> sidebarWidth;
  @override
  final CurvedAnimation sidebarAnimation;
  final MacosDesktopStyle style;
  final Widget customToobar;
  final VoidCallback onSidebarButtonPressed;
  final Widget resizeArea;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: style.toolbarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: sidebarWidthBuilder(
              builder: (sidebarWidth, animatedSidebarWidth, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: animatedSidebarWidth),
                    Expanded(
                      child: ColoredBox(color: style.toolbarBackgroundColor),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: _redYellowGreenWidth),
              child: MacosToolbarPassthroughScope(
                child: Row(
                  children: [
                    MacosToolbarPassthrough(child: _sidebarIconButton()),
                    sidebarWidthBuilder(
                      builder: (sidebarWidth, animatedSidebarWidth, _) {
                        final width =
                            animatedSidebarWidth -
                            _redYellowGreenWidth -
                            _sidebarButtonSize;
                        if (width <= 0) {
                          return SizedBox.shrink();
                        }
                        final resize =
                            sidebarAnimation.isCompleted &&
                            width > _resizeAreaWidth;
                        return SizedBox(
                          width: width,
                          height: style.toolbarHeight,
                          child:
                              resize
                                  ? Align(
                                    alignment: Alignment.centerRight,
                                    child: MacosToolbarPassthrough(
                                      child: resizeArea,
                                    ),
                                  )
                                  : null,
                        );
                      },
                    ),
                    const SizedBox(width: 4.0),
                    Expanded(child: customToobar),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          onPressed: onSidebarButtonPressed,
          icon: Icon(CupertinoIcons.sidebar_left, size: 18),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget with _SidebarWidthBase {
  const _Body({
    super.key,
    required this.sidebarWidth,
    required this.sidebarAnimation,
    required this.style,
    required this.sidebarBuilder,
    required this.resizeArea,
    required this.content,
  });

  @override
  final ValueListenable<double> sidebarWidth;
  @override
  final CurvedAnimation sidebarAnimation;
  final MacosDesktopStyle style;
  final Widget Function() sidebarBuilder;
  final Widget resizeArea;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return sidebarWidthBuilder(
      builder: (sidebarWidth, animatedSidebarWidth, child) {
        Widget? sidebar;
        if (animatedSidebarWidth > 0) {
          sidebar = ColoredBox(
            color: style.sidebarBackgroundColor,
            child: Column(
              children: [
                SizedBox(height: style.toolbarHeight),
                Expanded(child: sidebarBuilder()),
              ],
            ),
          );
          if (sidebarAnimation.isCompleted) {
            sidebar = Stack(
              children: [
                sidebar,
                Positioned.fill(left: null, child: resizeArea),
              ],
            );
          }
          sidebar = Positioned.fill(
            right: null,
            child: SizedBox(width: sidebarWidth, child: sidebar),
          );
        }

        Widget content = Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(height: style.toolbarHeight),
              Expanded(child: this.content),
            ],
          ),
        );
        if (animatedSidebarWidth > 0) {
          content = DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  offset: Offset.zero,
                  blurRadius: 0.5,
                ),
              ],
            ),
            child: content,
          );
        }

        return Stack(
          children: [
            if (sidebar != null) sidebar,
            Positioned.fill(
              left: animatedSidebarWidth,
              child: content, //  ColoredBox(color: Colors.red, child: content),
            ),
          ],
        );
      },
    );
  }
}
