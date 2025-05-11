import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../view_model/tree_node_data.dart';
import 'json_viewer_theme.dart';

class WidthData {
  final TreeSliverNode<TreeNodeData>? parent;
  double maxWidth;
  final double expend;
  final double fold;

  WidthData({
    required this.parent,
    required this.maxWidth,
    required this.expend,
    required this.fold,
  });
}

mixin TextWidthComputeBase {
  Map<TreeSliverNode<TreeNodeData>, WidthData> _widthCache = HashMap();

  TreeSliverNode<TreeNodeData> get rootNode;

  void computeTextWidthCache({
    required TextStyle textStyle,
    required JsonViewerThemeData themeData,
  }) {
    final tree = rootNode;

    final widthCache = HashMap<TreeSliverNode<TreeNodeData>, WidthData>();
    final computer = _TextWidthCacheComputer(
      style: textStyle,
      prefixWidth: themeData.prefixWidth,
      indentWidth: themeData.indentWidth,
      iconAndSpaceWidth: themeData.iconBoxSize + themeData.spaceAfterIcon,
      extraWidth: 20,
    );
    computer.computeTextWidthCache(tree, null, widthCache, 0);

    _widthCache = widthCache;
  }

  double getMaxWidth() {
    return _widthCache[rootNode]?.maxWidth ?? 0.0;
  }

  void updateMaxWidth(TreeSliverNode<Object?> node) {
    _notifyNodeWidth(node);
  }

  void _notifyNodeWidth(TreeSliverNode<Object?>? node) {
    if (node == null) {
      return;
    }
    final widthDataTmp = _widthCache[node];
    assert(widthDataTmp != null);
    final widthData = widthDataTmp!;

    final maxWidth = _computeNodeWidthFromCache(node, widthData);
    if ((widthData.maxWidth - maxWidth).abs() > 1e-10) {
      widthData.maxWidth = maxWidth;
      _notifyNodeWidth(widthData.parent);
    }
  }

  double _computeNodeWidthFromCache(
    TreeSliverNode<Object?> node,
    WidthData widthData,
  ) {
    if (!node.isExpanded) {
      return widthData.fold;
    }

    double maxWidth = 0.0;
    for (final child in node.children) {
      final childWidthData = _widthCache[child];
      assert(childWidthData != null);
      final childWidth = childWidthData!.maxWidth;
      if (childWidth > maxWidth) {
        maxWidth = childWidth;
      }
    }
    maxWidth = math.max(maxWidth, widthData.expend);
    return maxWidth;
  }
}

class _TextWidthCacheComputer {
  final TextStyle style;
  final double prefixWidth;
  final double indentWidth;
  final double iconAndSpaceWidth;
  final double extraWidth;

  late final bool monospace;
  late final double asciiWidth;

  late final double commaWidth;
  late final double colonSpaceWidth;
  late final double startArrayWidth;
  late final double endArrayWidth;
  late final double arrayFoldWidth;
  late final double startObjectWidth;
  late final double endObjectWidth;
  late final double objectFoldWidth;

  _TextWidthCacheComputer({
    required this.style,
    required this.prefixWidth,
    required this.indentWidth,
    required this.iconAndSpaceWidth,
    required this.extraWidth,
  }) {
    final width_i = calculateTextWidth('i');
    final width_M = calculateTextWidth('M');
    monospace = (width_i - width_M).abs() < 1e-10;
    asciiWidth = monospace ? width_i : 0.0;

    final double Function(String s) widthFunc;
    if (monospace) {
      widthFunc = (String s) => asciiWidth * s.length;
    } else {
      widthFunc = (String s) => calculateTextWidth(s);
    }

    commaWidth = widthFunc(',');
    colonSpaceWidth = widthFunc(': ');

    startArrayWidth = widthFunc('[');
    endArrayWidth = widthFunc(']');
    arrayFoldWidth = widthFunc('[...]');

    startObjectWidth = widthFunc('{');
    endObjectWidth = widthFunc('}');
    objectFoldWidth = widthFunc('{...}');
  }

  double computeTextWidthCache(
    TreeSliverNode<TreeNodeData> tree,
    TreeSliverNode<TreeNodeData>? parent,
    Map<TreeSliverNode<TreeNodeData>, WidthData> widthCache,
    int depth,
  ) {
    double max = 0.0;
    if (tree.children.isNotEmpty) {
      for (final child in tree.children) {
        final singleWidth = computeTextWidthCache(
          child,
          tree,
          widthCache,
          depth + 1,
        );
        if (singleWidth > max) {
          max = singleWidth;
        }
      }
    }
    final width = _computeSingleNode(tree, parent, depth, max);
    widthCache[tree] = width;
    return width.maxWidth;
  }

  WidthData _computeSingleNode(
    TreeSliverNode<TreeNodeData> node,
    TreeSliverNode<TreeNodeData>? parent,
    int depth,
    double childMaxWidth,
  ) {
    // Leaf
    // prefixWidth + indentWidth + [name + ': '] + content + [',']
    // Leaf - END
    // prefixWidth + indentWidth + ']' + [',']

    // Node
    // Expend: prefixWidth + indentWidth + [name +': '] + '['
    // Fold:   prefixWidth + indentWidth + [name +': '] + '[...]' + [',']

    final nodeData = node.content;

    // prefixWidth + indentWidth + extra
    double commonWidth = prefixWidth + indentWidth * depth + extraWidth;

    // [name +': ']
    final name = nodeData.name;
    if (name != null) {
      if (nodeData.isNameAllAscii) {
        commonWidth += asciiWidth * name.length;
      } else {
        commonWidth += calculateTextWidth(name);
      }
      commonWidth += colonSpaceWidth;
    }

    // content & comma
    if (node.children.isEmpty) {
      double width = commonWidth;
      if (nodeData.type == TreeNodeDataType.arrayEnd) {
        width += endArrayWidth;
      } else if (nodeData.type == TreeNodeDataType.objectEnd) {
        width += endObjectWidth;
      } else {
        if (nodeData.isTextAllAscii) {
          width += asciiWidth * nodeData.text.length;
        } else {
          width += calculateTextWidth(nodeData.text);
        }
      }
      if (nodeData.comma) {
        width += commaWidth;
      }
      return WidthData(
        expend: width,
        fold: width,
        maxWidth: width,
        parent: parent,
      );
    } else {
      final expendableCommonWidth = commonWidth + iconAndSpaceWidth;

      double expend = expendableCommonWidth;
      double fold = expendableCommonWidth;
      if (nodeData.type == TreeNodeDataType.arrayStart) {
        expend += startArrayWidth;
        fold += arrayFoldWidth;
      } else if (nodeData.type == TreeNodeDataType.objectStart) {
        expend += startObjectWidth;
        fold += objectFoldWidth;
      }
      if (nodeData.tail?.comma == true) {
        fold += commaWidth;
      }

      double maxWidth;
      if (node.isExpanded) {
        maxWidth = math.max(expend, childMaxWidth);
      } else {
        maxWidth = fold;
      }

      return WidthData(
        expend: expend,
        fold: fold,
        maxWidth: maxWidth,
        parent: parent,
      );
    }
  }

  double calculateTextWidth(String text) {
    return calculateTextSpanWidth(TextSpan(text: text, style: style));
  }
}

double calculateTextSpanWidth(TextSpan span) {
  final textPainter = TextPainter(
    text: span,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout();
  final width = textPainter.width;
  textPainter.dispose();

  return width;
}
