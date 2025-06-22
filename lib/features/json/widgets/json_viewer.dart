import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/search/search_field.dart';
import '../../../shared/widgets/search/search_theme.dart';
import '../service/sliver_tree_helper.dart';
import '../view_model/json_value_vm.dart';
import '../view_model/tree_node_data.dart';
import 'dynamic_width.dart';
import 'json_viewer_controller.dart';
import 'json_viewer_theme.dart';
import 'text_width.dart';

const _colonSpace = ': ';

class JsonViewer extends StatelessWidget {
  const JsonViewer({
    super.key,
    required this.controller,
    required this.themeData,
    required this.scrollIdH,
    required this.scrollIdV,
  });

  final JsonViewerController controller;
  final JsonViewerThemeData themeData;

  final String scrollIdH;
  final String scrollIdV;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(fontFamily: themeData.fontFamily, fontSize: themeData.fontSize),
    );
    return ValueListenableBuilder(
      valueListenable: controller.viewDataNotifier,
      builder: (BuildContext context, JsonViewerData value, Widget? child) {
        return Stack(
          children: [
            buildJsonViewer(value, textStyle),
            PositionedPopup(
              isVisibleListenable: controller.showSearchField,
              top: denseSpacing,
              right: 20,
              child: buildSearchInFileField(),
            ),
          ],
        );
      },
    );
  }

  Widget buildJsonViewer(JsonViewerData viewData, TextStyle textStyle) {
    final msg = viewData.errorMessage;
    final treeNode = viewData.treeNode;
    if (msg != null) {
      return Text(msg);
    } else if (treeNode == null) {
      return Container();
    } else {
      return InnerJsonViewer(
        controller: controller,
        themeData: themeData,
        textStyle: textStyle,
        treeNode: treeNode,
        scrollIdH: scrollIdH,
        scrollIdV: scrollIdV,
      );
    }
  }

  Widget buildSearchInFileField() {
    return Material(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: wideSearchFieldWidth,
        height: themeData.defaultTextFieldHeight + 2 * denseSpacing,
        // padding: const EdgeInsets.all(denseSpacing),
        padding: const EdgeInsets.symmetric(
          horizontal: denseSpacing,
          vertical: densePadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: Color(0xFFd6d6d6), width: 0.5),
        ),
        child: SearchTheme(
          theme: SearchThemeData(fontSize: themeData.fontSize),
          child: SearchField<JsonViewerController>(
            searchController: controller,
            searchFieldEnabled: true,
            supportsNavigation: true,
            // shouldRequestFocus: true,
            searchFieldWidth: wideSearchFieldWidth,
            searchFieldBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              gapPadding: 0.0,
            ),
            onClose: () => controller.closeSearchField(),
          ),
        ),
      ),
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

    required this.scrollIdH,
    required this.scrollIdV,
  });

  final JsonViewerController controller;
  final JsonViewerThemeData themeData;
  final TextStyle textStyle;
  final TreeSliverNode<TreeNodeData> treeNode;

  final String scrollIdH;
  final String scrollIdV;

  @override
  State<InnerJsonViewer> createState() => _InnerJsonViewerState();
}

class _InnerJsonViewerState extends State<InnerJsonViewer>
    with TextWidthComputeBase {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ValueNotifier<double> _maxWidthNotifier = ValueNotifier(0);

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
            key: PageStorageKey(widget.scrollIdH),
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
                      key: PageStorageKey(widget.scrollIdV),
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      jsonViewerController: widget.controller,
                      horizontalController: _horizontalController,
                      verticalController: _verticalController,
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
                      onTreeSliverNodeUpdate: () {
                        setState(() {
                          // TODO 不需要全部重新计算
                          computeTextWidthCache(
                            textStyle: widget.textStyle,
                            themeData: widget.themeData,
                          );
                        });
                      },
                      textStyle: widget.textStyle,
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

    required this.treeNode,
    required this.themeData,
    this.onNodeToggle,

    this.onTreeSliverNodeUpdate,

    required this.textStyle,
  });

  final double height;
  final double width;

  final JsonViewerController jsonViewerController;
  final ScrollController horizontalController;
  final ScrollController verticalController;

  final TreeSliverNode<TreeNodeData> treeNode;
  final JsonViewerThemeData themeData;
  final TreeSliverNodeCallback? onNodeToggle;

  final VoidCallback? onTreeSliverNodeUpdate;

  // TODO 更好的方式获取textStyle
  final TextStyle textStyle;

  @override
  State<_JsonViewerContent> createState() => _JsonViewerContentState();
}

class _JsonViewerContentState extends State<_JsonViewerContent> {
  final _treeSliverController = TreeSliverController();

  @override
  void initState() {
    super.initState();
    widget.jsonViewerController.activeSearchMatch.addListener(
      _onActiveSearchMatchChange,
    );
  }

  @override
  void dispose() {
    widget.jsonViewerController.activeSearchMatch.removeListener(
      _onActiveSearchMatchChange,
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _JsonViewerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TODO process _onActiveSearchMatchChange
  }

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
          controller: _treeSliverController,
          treeNodeBuilder: _treeNodeBuilder,
          treeRowExtentBuilder:
              (node, dimensions) => widget.themeData.defaultRowHeight,
          toggleAnimationStyle: AnimationStyle.noAnimation,
          indentation: TreeSliverIndentationType.none,
          onNodeToggle: widget.onNodeToggle,
        ),
      ],
    );
  }

  Widget _treeNodeBuilder(
    BuildContext context,
    TreeSliverNode<Object?> node,
    AnimationStyle animationStyle,
  ) {
    return ListenableBuilder(
      listenable: widget.jsonViewerController.searchMatches,
      builder: (context, child) {
        return ListenableBuilder(
          listenable: widget.jsonViewerController.activeSearchMatch,
          builder: (context, child) {
            return _JsonViewerLine(
              node: node as TreeSliverNode<TreeNodeData>,
              themeData: widget.themeData,
              treeSliverController: _treeSliverController,
              searchMatches: _searchMatchesForLine(node),
              onTreeSliverNodeUpdate: widget.onTreeSliverNodeUpdate,
            );
          },
        );
      },
    );
  }

  List<JsonViewFindMatch> _searchMatchesForLine(TreeSliverNode<Object?> node) {
    // TODO 使用map而不是遍历
    return widget.jsonViewerController.searchMatches.value
        .where((searchMatch) => searchMatch.path.data == node)
        .toList();
  }

  void _onActiveSearchMatchChange() {
    _expandAndScroll();
  }

  void _expandAndScroll() {
    final activeMatch = widget.jsonViewerController.activeSearchMatch.value;
    if (activeMatch == null) {
      return;
    }

    final currentPath = activeMatch.path;
    final nameLen = currentPath.data.content.name?.length ?? 0;
    if (activeMatch.end > nameLen + _colonSpace.length) {
      final currentNode = currentPath.data;
      if (currentNode.isExpanded) {
        _treeSliverController.toggleNode(currentPath.data);
      }
    }
    final prePath = currentPath.prev;
    if (prePath != null) {
      prePath.invokeFromRoot((node) {
        if (!node.isExpanded) {
          _treeSliverController.toggleNode(node);
        }
      });
    }

    final offsetLines = computeOffsetLines(activeMatch.path);

    _maybeScrollToPosition(offsetLines, activeMatch);
  }

  void _maybeScrollToPosition(int? lineNumber, JsonViewFindMatch activeMatch) {
    _maybeScrollToLine(widget.verticalController, lineNumber);
    _maybeScrollToColumn(widget.horizontalController, activeMatch);
  }

  void _maybeScrollToLine(ScrollController scrollController, int? lineNumber) {
    if (lineNumber == null) return;

    final rowHeight = widget.themeData.defaultRowHeight;

    final isOutOfViewTop =
        lineNumber * rowHeight < scrollController.offset + rowHeight;
    final isOutOfViewBottom =
        lineNumber * rowHeight >
        scrollController.offset + widget.height - rowHeight;

    if (isOutOfViewTop || isOutOfViewBottom) {
      // Scroll this search token to the middle of the view.
      final targetOffset = math.max<double>(
        lineNumber * rowHeight - widget.height / 2,
        0.0,
      );
      unawaited(
        scrollController.animateTo(
          targetOffset,
          duration: defaultDuration,
          curve: defaultCurve,
        ),
      );
    }
  }

  void _maybeScrollToColumn(
    ScrollController scrollController,
    JsonViewFindMatch activeMatch,
  ) {
    final node = activeMatch.path.data;

    final text = node.content.contactString();
    final preMatchText = text.substring(0, activeMatch.start);

    final textWidth = calculateTextSpanWidth(
      TextSpan(text: preMatchText, style: widget.textStyle),
    );
    final width =
        widget.themeData.prefixWidth +
        // TODO node.depth may be null
        node.depth! * widget.themeData.indentWidth +
        textWidth;

    final matchText = text.substring(
      activeMatch.start,
      activeMatch.start + activeMatch.length,
    );

    final matchTextWidth = calculateTextSpanWidth(
      TextSpan(text: matchText, style: widget.textStyle),
    );

    final matchHorizontalScrollSpace =
        widget.themeData.matchHorizontalScrollSpace;
    double? targetOffset;
    if (width < scrollController.offset) {
      // isOutOfViewLeft
      targetOffset = math.max(width - matchHorizontalScrollSpace, 0.0);
    } else if (width + matchTextWidth >
        scrollController.offset + widget.width) {
      // isOutOfViewRight && !isOutOfViewLeft

      if (matchTextWidth > widget.width) {
        targetOffset = math.max(width - matchHorizontalScrollSpace, 0.0);
      } else {
        targetOffset = math.min(
          width + matchTextWidth + matchHorizontalScrollSpace - widget.width,
          scrollController.position.maxScrollExtent,
        );
      }
    }

    if (targetOffset != null) {
      unawaited(
        scrollController.animateTo(
          targetOffset,
          duration: defaultDuration,
          curve: defaultCurve,
        ),
      );
    }
  }
}

class _JsonViewerLine extends StatelessWidget {
  const _JsonViewerLine({
    super.key,
    required this.themeData,
    required this.node,
    required this.treeSliverController,
    required this.searchMatches,
    this.onTreeSliverNodeUpdate,
  });

  final JsonViewerThemeData themeData;
  final TreeSliverNode<TreeNodeData> node;
  final TreeSliverController treeSliverController;
  final List<JsonViewFindMatch> searchMatches;
  final VoidCallback? onTreeSliverNodeUpdate;

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

    _buildContent(indentDepth, widgets, context);

    final refExpandButton = _buildRefExpandButton();
    if (refExpandButton != null) {
      widgets.add(SizedBox(width: 8));
      widgets.add(refExpandButton);
    }

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

  // TODO 重新计算最大宽度
  Widget? _buildRefExpandButton() {
    final nodeData = node.content;

    Widget? refExpand;
    final contentJsonValue = node.content.ref;
    if (node.isExpanded &&
        contentJsonValue != null &&
        contentJsonValue is NormalJsonObjectVM) {
      final fastJsonRef = contentJsonValue.ref;
      if (fastJsonRef != null) {
        refExpand = GestureDetector(
          onTap: () {
            final JsonValueVM treeNeedToShow;
            if (nodeData.showRef) {
              treeNeedToShow = contentJsonValue;
            } else {
              treeNeedToShow = fastJsonRef;
            }

            final refSliverTree = buildTreeNodes(treeNeedToShow);

            if (refSliverTree.children.isNotEmpty) {
              node.children.clear();
              node.children.addAll(refSliverTree.children);
            }

            // TODO 与内容相关的属性放到一起
            // nodeData.text = refSliverTree.content.text;
            // nodeData.collapsedTail = refSliverTree.content.collapsedTail;
            // nodeData.shortString = refSliverTree.content.shortString;
            // nodeData.hint = refSliverTree.content.hint;

            // TODO shortString 处理

            // 不需要setState，toggleNode会触发重建
            nodeData.showRef = !nodeData.showRef;

            onTreeSliverNodeUpdate?.call();
          },
          child: AnimatedContainer(
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color:
                  nodeData.showRef
                      ? Colors.blueGrey.shade100
                      : themeData.color.background,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: SizedBox.square(
                dimension: themeData.iconBoxSize,
                child: Icon(
                  // TODO switch icon
                  Icons.expand,
                  size: themeData.iconSize,
                ),
              ),
            ),
          ),
        );
      }
    }
    return refExpand;
  }

  void _buildContent(
    int indentDepth,
    List<Widget> widgets,
    BuildContext context,
  ) {
    final nodeData = node.content;
    final textStyleTheme = themeData.textStyle;

    List<InlineSpan>? nameSpans;
    final name = nodeData.name;
    if (name != null) {
      nameSpans = [
        TextSpan(text: name, style: textStyleTheme.objectKey),
        TextSpan(text: _colonSpace, style: textStyleTheme.colon),
      ];
    }

    final contentStyle = _getContentStyle(
      nodeData.type,
      indentDepth,
      textStyleTheme,
    );

    if (!node.isExpanded &&
        node.children.isNotEmpty &&
        nodeData.parsedStart == null) {
      if (nameSpans != null) {
        widgets.add(
          Text.rich(
            TextSpan(children: searchAwareLineContents(nameSpans, context)),
          ),
        );
      }

      final TextSpan collapse;
      if (nodeData.shortString != null) {
        final t = ' ${nodeData.shortString} ';
        collapse = TextSpan(text: t, style: textStyleTheme.shortString);
      } else {
        collapse = TextSpan(text: '...', style: textStyleTheme.foldForeground);
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
                collapse,
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
    } else {
      // TODO 样式 && 宽度计算
      final List<InlineSpan> spans = nameSpans ?? <InlineSpan>[];

      if (node.isExpanded && nodeData.parsedStart != null) {
        spans.add(
          TextSpan(
            text: nodeData.parsedStart,
            style: _getContentStyle(
              nodeData.parsedType!,
              indentDepth,
              textStyleTheme,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: nodeData.text, style: contentStyle));
        if (nodeData.comma) {
          spans.add(TextSpan(text: ',', style: textStyleTheme.comma));
        }
      }

      widgets.add(
        Text.rich(TextSpan(children: searchAwareLineContents(spans, context))),
      );

      final hintString = nodeData.hintString;
      if (hintString != null) {
        widgets.add(SizedBox(width: 8));
        widgets.add(Text('// $hintString', style: textStyleTheme.hint));
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

  List<InlineSpan> searchAwareLineContents(
    List<InlineSpan> spans,
    BuildContext context,
  ) {
    if (searchMatches.isNotEmpty) {
      for (final match in searchMatches) {
        final matchColor =
            match.isActiveSearchMatch
                ? themeData.color.activeFindMatchBackground
                : themeData.color.findMatchBackground;

        spans = _contentsWithMatch(spans, match, matchColor, context: context);
      }
    }
    return spans;
  }

  List<InlineSpan> _contentsWithMatch(
    List<InlineSpan> startingContents,
    JsonViewFindMatch match,
    Color matchColor, {
    required BuildContext context,
  }) {
    final contentsWithMatch = <InlineSpan>[];
    var startColumnForSpan = 0;
    for (final span in startingContents) {
      final spanText = span.toPlainText();
      // TODO
      final startColumnForMatch = match.start;
      if (startColumnForSpan <= startColumnForMatch &&
          startColumnForSpan + spanText.length > startColumnForMatch) {
        // The active search is part of this [span].
        final matchStartInSpan = startColumnForMatch - startColumnForSpan;
        final matchEndInSpan = matchStartInSpan + match.length;

        // Add the part of [span] that occurs before the search match.
        contentsWithMatch.add(
          TextSpan(
            text: spanText.substring(0, matchStartInSpan),
            style: span.style,
          ),
        );

        final matchStyle = (span.style ?? DefaultTextStyle.of(context).style)
            .copyWith(color: Colors.black, backgroundColor: matchColor);

        if (matchEndInSpan <= spanText.length) {
          final matchText = spanText.substring(
            matchStartInSpan,
            matchEndInSpan,
          );
          final trailingText = spanText.substring(matchEndInSpan);
          // Add the match and any part of [span] that occurs after the search
          // match.
          contentsWithMatch.addAll([
            TextSpan(text: matchText, style: matchStyle),
            if (trailingText.isNotEmpty)
              TextSpan(
                text: spanText.substring(matchEndInSpan),
                style: span.style,
              ),
          ]);
        } else {
          // In this case, the active search match exists across multiple spans,
          // so we need to add the part of the match that is in this [span] and
          // continue looking for the remaining part of the match in the spans
          // to follow.
          contentsWithMatch.add(
            TextSpan(
              text: spanText.substring(matchStartInSpan),
              style: matchStyle,
            ),
          );
          final remainingMatchLength =
              match.length - (spanText.length - matchStartInSpan);
          match = JsonViewFindMatch(
            path: match.path,
            start: startColumnForMatch + match.length - remainingMatchLength,
            end: startColumnForMatch + match.length,
          );
        }
      } else {
        contentsWithMatch.add(span);
      }
      startColumnForSpan += spanText.length;
    }
    return contentsWithMatch;
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

class PositionedPopup extends StatelessWidget {
  const PositionedPopup({
    super.key,
    required this.isVisibleListenable,
    required this.child,
    this.top,
    this.left,
    this.right,
  });

  final ValueListenable<bool> isVisibleListenable;
  final double? top;
  final double? left;
  final double? right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isVisibleListenable,
      builder: (context, isVisible, _) {
        return isVisible
            ? Positioned(top: top, left: left, right: right, child: child)
            : const SizedBox.shrink();
      },
    );
  }
}
