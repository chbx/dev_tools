import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';

class TabData {
  TabData({required this.id, required this.tabName});

  final int id;

  final String tabName;
}

class TabView extends StatefulWidget {
  const TabView({
    super.key,
    required this.selectedIndex,
    required this.tabData,
    this.onClosed,
    this.onSelected,
    this.onCreated,
  });

  final List<TabData> tabData;
  final int selectedIndex;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildTabs(widget.tabData),
            ),
          ),
        ),
        SizedBox(width: 60),
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
            name: tabData.tabName,
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

    final radius = 6.0;
    BorderRadius? borderRadius;
    EdgeInsetsGeometry? padding;
    if (widget.selected) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      );
      padding = const EdgeInsets.only(top: 4.0);
    } else if (WidgetState.hovered.isSatisfiedBy(_states)) {
      borderRadius = BorderRadius.all(Radius.circular(radius));
      padding = const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0);
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
        child: Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -radius,
              right: -radius,
              bottom: 0,
              child: SizedBox(
                height: radius,
                child:
                    widget.selected
                        ? CustomPaint(
                          painter: InnerRoundedRectanglePainter(
                            color:widget.selectColor,
                            radius: radius,
                          ),
                        )
                        : null,
              ),
            ),
            Positioned.fill(
              child: _ColorAnimated(
                padding: padding,
                duration:
                    widget.selected
                        ? Duration.zero
                        : Duration(milliseconds: 120),
                color: bgColor,
                borderRadius: borderRadius,
                child: SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 12.0, right: 8.0),
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
          ],
        ),
      ),
    );
  }
}

class _ColorAnimated extends ImplicitlyAnimatedWidget {
  const _ColorAnimated({
    super.key,
    required super.duration,

    required this.color,
    this.padding,
    this.borderRadius,
    required this.child,
  });

  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  AnimatedWidgetBaseState<_ColorAnimated> createState() =>
      _ColorAnimatedState();
}

class _ColorAnimatedState extends AnimatedWidgetBaseState<_ColorAnimated> {
  late final ColorTween _color = ColorTween(
    begin: widget.color,
    end: widget.color,
  );
  BorderRadiusGeometry? _borderRadius;
  EdgeInsetsGeometry? _padding;

  @override
  void initState() {
    super.initState();
    _borderRadius = widget.borderRadius;
    _padding = widget.padding;
    controller.addStatusListener((AnimationStatus status) {
      if (status.isCompleted) {
        _borderRadius = widget.borderRadius;
        _padding = widget.padding;
      }
      if (_borderRadius == null && widget.borderRadius != null) {
        _borderRadius = widget.borderRadius;
      }
      if (_padding == null && widget.padding != null) {
        _padding = widget.padding;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ColorAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.forward(from: 0.0);
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _color
      ..begin = _color.evaluate(animation)
      ..end = widget.color;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = this.animation;
    return Padding(
      padding: _padding ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _color.evaluate(animation),
          borderRadius: _borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

// ClipPath(
//   clipper: InwardRoundedTopRectClipper(radius: radius),
//   child: Container(color: Colors.red),
// )
class InwardRoundedTopRectClipper extends CustomClipper<Path> {
  final double radius;

  InwardRoundedTopRectClipper({required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path();

    // 从左上角圆弧结束点开始
    path.moveTo(0, radius);

    // 左上四分之一圆（向内切）
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(size.width - radius, 0);

    // 右上四分之一圆（向内切）
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    // 右侧直线
    path.lineTo(size.width, size.height);

    // 底部直线
    path.lineTo(0, size.height);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldCliper) {
    return true;
  }
}

class InnerRoundedRectanglePainter extends CustomPainter {
  final Color color;
  final double radius;
  InnerRoundedRectanglePainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();

    // 从左上角圆弧结束点开始
    path.moveTo(0, radius);

    // 左上四分之一圆（向内切）
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(size.width - radius, 0);

    // 右上四分之一圆（向内切）
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    // 右侧直线
    path.lineTo(size.width, size.height);

    // 底部直线
    path.lineTo(0, size.height);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant InnerRoundedRectanglePainter old) {
    return old.color != color || old.radius != radius;
  }
}
