import 'package:flutter/widgets.dart';

class JsonViewerIndent extends LeafRenderObjectWidget {
  const JsonViewerIndent({
    super.key,
    required this.indentWidth,
    required this.indent,
    required this.height,
    required this.color,
  });

  final double height;
  final double indentWidth;
  final int indent;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderJsonViewerIndent(
      height: height,
      indentWidth: indentWidth,
      indent: indent,
      color: color,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderJsonViewerIndent renderObject,
  ) {
    renderObject.update(
      height: height,
      indent: indent,
      indentWidth: indentWidth,
      color: color,
    );
  }
}

class RenderJsonViewerIndent extends RenderBox {
  double _height;
  double _indentWidth;
  int _indent;

  final Path _path;
  final Paint _pen =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

  RenderJsonViewerIndent({
    required double height,
    required double indentWidth,
    required int indent,
    required Color color,
  }) : _height = height,
       _indent = indent,
       _indentWidth = indentWidth,
       _path = Path() {
    _buildPath();
    _pen.color = color;
  }

  void _buildPath() {
    for (var i = 0; i < _indent; i++) {
      _path.moveTo(_indentWidth * i, 0.0);
      _path.lineTo(_indentWidth * i, _height);
    }
  }

  void update({
    double? height,
    double? indentWidth,
    int? indent,
    Color? color,
  }) {
    bool anySizeChanged = false;
    if (height != null && _height != height) {
      _height = height;
      anySizeChanged = true;
    }
    if (indentWidth != null && _indentWidth != indentWidth) {
      _indentWidth = indentWidth;
      anySizeChanged = true;
    }
    if (indent != null && _indent != indent) {
      _indent = indent;
      anySizeChanged = true;
    }

    bool colorChanged = false;
    if (color != null && _pen.color != color) {
      _pen.color = color;
      colorChanged = true;
    }

    if (anySizeChanged) {
      _path.reset();
      _buildPath();
      markNeedsLayout();
    }
    if (colorChanged || anySizeChanged) {
      markNeedsPaint();
    }
  }

  @override
  void performLayout() {
    size = Size(_indentWidth * _indent, _height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawPath(_path.shift(offset), _pen);
  }
}
