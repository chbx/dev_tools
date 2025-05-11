import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../view_model/tree_node_data.dart';
import 'dynamic_width.dart';
import 'json_viewer_controller.dart';
import 'json_viewer_theme.dart';
import 'text_width.dart';

class JsonViewer extends StatelessWidget {
  const JsonViewer({
    super.key,
    required this.controller,
    required this.themeData,
  });

  final JsonViewerController controller;
  final JsonViewerThemeData themeData;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(fontFamily: themeData.fontFamily, fontSize: themeData.fontSize),
    );
    return ValueListenableBuilder(
      valueListenable: controller.viewDataNotifier,
      builder: (BuildContext context, JsonViewerData value, Widget? child) {
        final msg = value.errorMessage;
        if (msg != null) {
          return Text(msg);
        }
        final treeNode = value.treeNode;
        if (treeNode == null) {
          return Container();
        }
        return InnerJsonViewer(
          controller: controller,
          themeData: themeData,
          textStyle: textStyle,
          treeNode: treeNode,
        );
      },
    );
  }
}

class InnerJsonViewer extends StatefulWidget {
  const InnerJsonViewer({
    super.key,
    required this.controller,
    required this.themeData,
    required this.textStyle,
    required this.treeNode,
  });

  final JsonViewerController controller;
  final JsonViewerThemeData themeData;
  final TextStyle textStyle;
  final TreeSliverNode<TreeNodeData> treeNode;

  @override
  State<InnerJsonViewer> createState() => _InnerJsonViewerState();
}

class _InnerJsonViewerState extends State<InnerJsonViewer>
    with TextWidthComputeBase {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ValueNotifier<double> _maxWidthNotifier = ValueNotifier(0);
  final TreeSliverController _treeSliverController = TreeSliverController();

  @override
  TreeSliverNode<TreeNodeData> get rootNode => widget.treeNode;

  @override
  void initState() {
    super.initState();
    _computeTextWidthCache();
  }

  @override
  void didUpdateWidget(covariant InnerJsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.treeNode, oldWidget.treeNode) ||
        widget.textStyle != oldWidget.textStyle) {
      _computeTextWidthCache();
    }
  }

  void _computeTextWidthCache() {
    computeTextWidthCache(
      textStyle: widget.textStyle,
      themeData: widget.themeData,
    );
  }

  @override
  void dispose() {
    _maxWidthNotifier.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      notificationPredicate: (notification) => notification.depth == 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxWidthNotifier.value = math.max(
            constraints.maxWidth,
            getMaxWidth(),
          );
          return Scrollbar(
            thumbVisibility: true,
            controller: _horizontalController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: DynamicWidthContainer(
                widthNotifier: _maxWidthNotifier,
                height: constraints.maxHeight,
                child: SelectionArea(
                  child: DefaultTextStyle(
                    style: widget.textStyle,
                    child: _JsonViewerContent(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      jsonViewerController: widget.controller,
                      horizontalController: _horizontalController,
                      verticalController: _verticalController,
                      treeSliverController: _treeSliverController,
                      treeNode: widget.treeNode,
                      themeData: widget.themeData,
                      onNodeToggle: (node) {
                        updateMaxWidth(node);
                        final maxWidth = math.max(
                          constraints.maxWidth,
                          getMaxWidth(),
                        );
                        _maxWidthNotifier.value = maxWidth;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JsonViewerContent extends StatefulWidget {
  const _JsonViewerContent({
    super.key,

    required this.height,
    required this.width,

    required this.jsonViewerController,
    required this.horizontalController,
    required this.verticalController,
    required this.treeSliverController,

    required this.treeNode,
    required this.themeData,
    this.onNodeToggle,
  });

  final double height;
  final double width;

  final JsonViewerController jsonViewerController;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final TreeSliverController treeSliverController;

  final TreeSliverNode<TreeNodeData> treeNode;
  final JsonViewerThemeData themeData;
  final TreeSliverNodeCallback? onNodeToggle;

  @override
  State<_JsonViewerContent> createState() => _JsonViewerContentState();
}

class _JsonViewerContentState extends State<_JsonViewerContent> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      scrollBehavior: ScrollConfiguration.of(
        context,
      ).copyWith(scrollbars: false),
      controller: widget.verticalController,
      slivers: [
        TreeSliver(
          tree: [widget.treeNode],
          controller: widget.treeSliverController,
          treeNodeBuilder: (context, node, animationStyle) {
            return _JsonViewerLine(
              node: node as TreeSliverNode<TreeNodeData>,
              themeData: widget.themeData,
              treeSliverController: widget.treeSliverController,
            );
          },
          treeRowExtentBuilder:
              (node, dimensions) => widget.themeData.defaultRowHeight,
          toggleAnimationStyle: AnimationStyle.noAnimation,
          indentation: TreeSliverIndentationType.none,
          onNodeToggle: widget.onNodeToggle,
        ),
      ],
    );
  }
}

class _JsonViewerLine extends StatelessWidget {
  const _JsonViewerLine({
    super.key,
    required this.themeData,
    required this.node,
    required this.treeSliverController,
  });

  final JsonViewerThemeData themeData;
  final TreeSliverNode<TreeNodeData> node;
  final TreeSliverController treeSliverController;

  @override
  Widget build(BuildContext context) {
    final content = node.content;

    final oriDepth = node.depth!;
    final indentDepth = content.isEnd ? oriDepth - 1 : oriDepth;

    final widgets = <Widget>[];
    _buildIndent(indentDepth, widgets);

    final isExpandable = node.children.isNotEmpty;
    if (isExpandable) {
      widgets.add(
        _SimpleButton(
          onPressed: () {
            treeSliverController.toggleNode(node);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all()),
            child: SizedBox.square(
              dimension: themeData.iconBoxSize,
              child: Icon(
                node.isExpanded ? Icons.remove : Icons.add,
                size: themeData.iconSize,
              ),
            ),
          ),
        ),
      );
      widgets.add(SizedBox(width: themeData.spaceAfterIcon));
    }

    _buildContent(indentDepth, widgets);

    return Row(children: widgets);
  }

  void _buildIndent(int indentDepth, List<Widget> widgets) {
    final border = BorderSide(width: 1, color: themeData.color.indentLine);
    widgets.add(
      SizedBox(
        height: themeData.defaultRowHeight,
        width: themeData.prefixWidth,
      ),
    );
    for (int i = 0; i < indentDepth; i++) {
      widgets.add(
        SizedBox(
          height: themeData.defaultRowHeight,
          width: themeData.indentWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: node.parent != null ? Border(left: border) : null,
            ),
          ),
        ),
      );
    }
  }

  void _buildContent(int indentDepth, List<Widget> widgets) {
    final nodeData = node.content;
    final textStyleTheme = themeData.textStyle;

    final contentStyle = _getContentStyle(
      nodeData.type,
      indentDepth,
      textStyleTheme,
    );
    if (node.isExpanded || node.children.isEmpty) {
      final spans = <InlineSpan>[];
      final name = nodeData.name;
      if (name != null) {
        spans.add(TextSpan(text: name, style: textStyleTheme.objectKey));
        spans.add(TextSpan(text: ": ", style: textStyleTheme.colon));
      }
      spans.add(TextSpan(text: nodeData.text, style: contentStyle));
      if (nodeData.comma) {
        spans.add(TextSpan(text: ',', style: textStyleTheme.comma));
      }
      widgets.add(Text.rich(TextSpan(children: spans)));
    } else {
      final name = nodeData.name;
      if (name != null) {
        widgets.add(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: name, style: textStyleTheme.objectKey),
                TextSpan(text: ": ", style: textStyleTheme.colon),
              ],
            ),
          ),
        );
      }
      widgets.add(
        _SimpleButton(
          onPressed: () {
            treeSliverController.toggleNode(node);
          },
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: nodeData.text, style: contentStyle),
                TextSpan(text: '...', style: textStyleTheme.foldForeground),
                TextSpan(text: nodeData.tail!.text, style: contentStyle),
              ],
              style: textStyleTheme.foldBackground,
            ),
          ),
        ),
      );

      if (nodeData.tail?.comma == true) {
        widgets.add(Text(',', style: textStyleTheme.comma));
      }
    }
  }

  TextStyle? _getContentStyle(
    TreeNodeDataType type,
    int depth,
    JsonViewerTextStyle theme,
  ) {
    final textStyle = switch (type) {
      TreeNodeDataType.string => theme.string,
      TreeNodeDataType.number => theme.number,
      TreeNodeDataType.literalTrue => theme.literal,
      TreeNodeDataType.literalFalse => theme.literal,
      TreeNodeDataType.literalNull => theme.literal,
      TreeNodeDataType.object ||
      TreeNodeDataType.objectStart ||
      TreeNodeDataType.objectEnd ||
      TreeNodeDataType.array ||
      TreeNodeDataType.arrayStart ||
      TreeNodeDataType.arrayEnd => _getBracketStyle(theme.brackets, depth),
    };
    return textStyle;
  }

  TextStyle? _getBracketStyle(List<TextStyle>? brackets, int depth) {
    TextStyle? textStyle;
    if (brackets != null && brackets.isNotEmpty) {
      textStyle = brackets[depth % brackets.length];
    }
    return textStyle;
  }
}

class _SimpleButton extends StatelessWidget {
  const _SimpleButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const cursor = SystemMouseCursors.click;
    return MouseRegion(
      cursor: cursor,
      child: DefaultSelectionStyle.merge(
        mouseCursor: cursor,
        child: GestureDetector(onTap: onPressed, child: child),
      ),
    );
  }
}
