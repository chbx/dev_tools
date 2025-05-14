import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../common.dart';
import '../search.dart';
import 'json_view_model.dart';
import 'parser/parser.dart';

const double _prefixWidth = 28;
const double _rowExtent = 24.0;
const double _rowHeight = 24.0;

const double _iconSize = 12;
const double _iconBoxSize = 16;
const double _iconAfterSpace = 4;
const double _matchHorizontalScrollSpace = 16.0;

class ColorTheme {
  final Color? key;
  final Color? string;
  final Color? literal;
  final Color? number;
  final List<Color>? brackets;
  final Color? colon;
  final Color? comma;
  final Color? indent;
  final Color findMatchBackground;
  final Color activeFindMatchBackground;

  const ColorTheme({
    this.key,
    this.string,
    this.literal,
    this.number,
    this.brackets,
    this.colon,
    this.comma,
    this.indent,
    required this.findMatchBackground,
    required this.activeFindMatchBackground,
  });
}

const Color _defaultIndentColor = Color(0xFFd3d3d3);
final ColorTheme defaultTheme = ColorTheme(
  key: Color(0xFF0451a5),
  string: Color(0xFFa31515),
  literal: Color(0xFF0000ff),
  number: Color(0xFF098658),
  brackets: [Color(0xFF0431fa), Color(0xFF319331), Color(0xFF7b3814)],
  colon: Color(0xFF3b3b3b),
  comma: Color(0xFF3b3b3b),
  indent: _defaultIndentColor,
  // TODO
  findMatchBackground: Colors.amberAccent.withValues(alpha: 0.6),
  activeFindMatchBackground: Colors.redAccent.withValues(alpha: 0.6),
);

class JsonViewFindMatch with SearchableDataMixin {
  final TreeSliverNode<TreeNodeData> ref;
  final List<TreeSliverNode<TreeNodeData>> path;
  final int start;
  final int end;
  final int length;

  JsonViewFindMatch({
    required this.ref,
    required this.path,
    required this.start,
    required this.end,
  }) : length = end - start;
}

class JsonViewerController with SearchControllerMixin<JsonViewFindMatch> {
  _JsonViewerState? _state;

  JsonViewerController() {
    init();
  }

  String? getTextContent() {
    var jsonValue = _state?._jsonValue;
    if (jsonValue == null) {
      return null;
    }

    var toStringHelper = ToStringHelper(whitespace: false, deepParse: true);
    var buffer = StringBuffer();
    toStringHelper.toJsonString(buffer, jsonValue);
    return buffer.toString();
  }

  void collapseAll() {
    // treeSliverController.collapseAll() 当数据量很大时，这个方法有性能问题
    var state = _state;
    if (state != null) {
      var jsonValue = state._jsonValue;
      if (jsonValue != null) {
        state._updateState(() {
          state._treeNode = buildTreeNodes(jsonValue, defaultExpand: false);

          // TODO
          refreshSearchMatches();
        });
      }
    }
  }

  void expandAll() {
    var state = _state;
    if (state != null) {
      var jsonValue = state._jsonValue;
      if (jsonValue != null) {
        state._updateState(() {
          state._treeNode = buildTreeNodes(jsonValue);

          // TODO
          refreshSearchMatches();
        });
      }
    }
  }

  @override
  List<JsonViewFindMatch> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    var treeNode = _state?._treeNode;

    if (treeNode == null) {
      return [];
    }

    // TODO
    search = search.toLowerCase();

    var allMatches = <JsonViewFindMatch>[];
    if (searchPreviousMatches) {
      var previousMatches = searchMatches.value;

      var nodes = HashSet<TreeSliverNode<TreeNodeData>>();
      for (final previousMatch in previousMatches) {
        var notExist = nodes.add(previousMatch.ref);
        if (notExist) {
          _searchNode(
            previousMatch.ref,
            previousMatch.path,
            search,
            allMatches,
          );
        }
      }
    } else {
      _searchTree(treeNode, [treeNode], search, allMatches);
    }

    return allMatches;
  }

  void _searchTree(
    TreeSliverNode<TreeNodeData> node,
    List<TreeSliverNode<TreeNodeData>> path,
    String search,
    List<JsonViewFindMatch> allMatches,
  ) {
    _searchNode(node, path, search, allMatches);
    for (var child in node.children) {
      _searchTree(child, [...path, child], search, allMatches);
    }
  }

  void _searchNode(
    TreeSliverNode<TreeNodeData> node,
    List<TreeSliverNode<TreeNodeData>> path,
    String search,
    List<JsonViewFindMatch> allMatches,
  ) {
    var content = node.content.stringForFind;
    var matches = search.allMatches(content);
    for (var match in matches) {
      allMatches.add(
        JsonViewFindMatch(
          start: match.start,
          end: match.end,
          ref: node,
          path: path,
        ),
      );
    }
  }

  @override
  void onMatchChanged(int index, bool fromNavigation) {}

  void dispose() {
    searchDispose();
  }
}

class JsonViewer extends StatefulWidget {
  final String text;
  final JsonViewerController controller;
  final ColorTheme? theme;
  final String? fontFamily;

  const JsonViewer({
    super.key,
    required this.controller,
    required this.text,
    this.theme,
    this.fontFamily,
  });

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ValueNotifier<double> _maxWidthNotifier = ValueNotifier(0);
  final TreeSliverController _treeSliverController = TreeSliverController();

  JsonValueVM? _jsonValue;
  TreeSliverNode<TreeNodeData>? _treeNode;
  String? _errorMessage;

  @override
  void dispose() {
    _maxWidthNotifier.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    assert(
      widget.controller._state == null,
      'The provided JsonViewerController is already associated with another '
      'JsonViewer. A JsonViewerController can only be associated with one '
      'JsonViewer.',
    );
    widget.controller._state = this;

    parse();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant JsonViewer oldWidget) {
    var controller = widget.controller;
    if (!identical(controller, oldWidget.controller)) {
      oldWidget.controller._state = null;
      controller._state = this;
    }

    if (oldWidget.text != widget.text) {
      parse();
    }

    super.didUpdateWidget(oldWidget);
  }

  void parse() {
    JsonValueVM? displayVM;
    String? errorMessage;
    try {
      var text = widget.text;
      if (text.isNotEmpty) {
        var jsonValue = Parser.parse(widget.text);
        displayVM = displayParse(jsonValue);
      }
    } catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      errorMessage = '解析异常';
    }
    _jsonValue = displayVM;
    _errorMessage = errorMessage;

    if (displayVM != null) {
      _treeNode = buildTreeNodes(displayVM);
    } else {
      _treeNode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    var msg = _errorMessage;
    if (msg != null) {
      return Text(msg);
    }
    var treeNode = _treeNode;
    var jsonValue = _jsonValue;
    if (treeNode == null || jsonValue == null) {
      return Text('Empty');
    }

    var textStyle = DefaultTextStyle.of(
      context,
    ).style.merge(TextStyle(fontFamily: widget.fontFamily));

    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      notificationPredicate: (notification) => notification.depth == 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxWidthNotifier.value = math.max(
            constraints.maxWidth,
            computeWidth(treeNode, widget.theme, textStyle),
          );
          return Scrollbar(
            thumbVisibility: true,
            controller: _horizontalController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: _SizeUpdateContainer(
                maxWidthNotifier: _maxWidthNotifier,
                height: constraints.maxHeight,
                child: SelectionArea(
                  child: DefaultTextStyle(
                    style: textStyle,
                    child: _JsonViewerContent(
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      jsonViewerController: widget.controller,
                      horizontalController: _horizontalController,
                      verticalController: _verticalController,
                      treeSliverController: _treeSliverController,
                      treeNode: treeNode,
                      colorTheme: widget.theme,
                      textStyle: textStyle,
                      onNodeToggle: (node) {
                        _maxWidthNotifier.value = math.max(
                          constraints.maxWidth,
                          computeWidth(treeNode, widget.theme, textStyle),
                        );
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

  double computeWidth(
    TreeSliverNode<TreeNodeData> treeNode,
    ColorTheme? theme,
    TextStyle textStyle,
  ) {
    var t = _findLongestText(treeNode);

    var textSpan = TextSpan(
      children: t.content.computeTextSpan(
        expanded: t.expanded,
        hasChild: t.hasChild,
        indentDepth: t.depth,
        theme: theme,
      ),
      style: textStyle,
    );

    var textWidth = calculateTextSpanWidth(textSpan);

    var width =
        _prefixWidth +
        t.depth * _rowExtent +
        _iconBoxSize +
        _iconAfterSpace +
        textWidth +
        10;

    return width;
  }

  void _updateState(VoidCallback fn) {
    setState(fn);
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
    this.colorTheme,
    required this.textStyle,
    this.onNodeToggle,
  });

  final double height;
  final double width;

  final JsonViewerController jsonViewerController;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final TreeSliverController treeSliverController;

  final TreeSliverNode<TreeNodeData> treeNode;
  final ColorTheme? colorTheme;
  final TreeSliverNodeCallback? onNodeToggle;
  final TextStyle textStyle;

  @override
  State<_JsonViewerContent> createState() => _JsonViewerContentState();
}

class _JsonViewerContentState extends State<_JsonViewerContent> {
  @override
  void initState() {
    widget.jsonViewerController.activeSearchMatch.addListener(
      _onActiveSearchMatchChange,
    );
    super.initState();
  }

  @override
  void dispose() {
    widget.jsonViewerController.activeSearchMatch.removeListener(
      _onActiveSearchMatchChange,
    );
    super.dispose();
  }

  void _onActiveSearchMatchChange() {
    _scroll();
  }

  void _scroll() {
    var activeMatch = widget.jsonViewerController.activeSearchMatch.value;
    if (activeMatch == null) {
      return;
    }
    var treeNode = widget.treeNode;

    for (var node in activeMatch.path.sublist(0, activeMatch.path.length - 1)) {
      if (!node.isExpanded) {
        widget.treeSliverController.toggleNode(node);
      }
    }
    var offsetLines = _computeOffsetLines(treeNode, activeMatch.path);
    _maybeScrollToLine(widget.verticalController, offsetLines);
    _maybeScrollToColumn(widget.horizontalController, activeMatch);
  }

  int _computeOffsetLines(
    TreeSliverNode<TreeNodeData> treeNode,
    List<TreeSliverNode<TreeNodeData>> path,
  ) {
    return _countLines(treeNode, path.sublist(1));
  }

  int _countLines(
    TreeSliverNode<TreeNodeData> nodeTree,
    List<TreeSliverNode<TreeNodeData>>? path,
  ) {
    if (path != null && path.isNotEmpty) {
      var node = path.first;
      var count = 0;
      for (var child in nodeTree.children) {
        count += 1;
        if (child == node) {
          var remainPath = path.sublist(1);
          if (remainPath.isNotEmpty) {
            count += _countLines(child, remainPath);
          }

          break;
        } else {
          count += _countLines(child, null);
        }
      }
      return count;
    } else {
      if (nodeTree.isExpanded) {
        var count = nodeTree.children.length;
        for (var child in nodeTree.children) {
          count += _countLines(child, null);
        }
        return count;
      } else {
        return 0;
      }
    }
  }

  void _maybeScrollToLine(ScrollController scrollController, int? lineNumber) {
    if (lineNumber == null) return;
    final rowHeight = _rowHeight;

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
    var node = activeMatch.ref;
    var spans = node.content.computeTextSpan(
      expanded: node.isExpanded,
      hasChild: node.children.isNotEmpty,
      indentDepth: node.depth!,
      theme: null,
    );

    var text = TextSpan(children: spans).toPlainText();
    var preMatchText = text.substring(0, activeMatch.start);
    final textPainter = TextPainter(
      //TODO style
      text: TextSpan(text: preMatchText, style: widget.textStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = _prefixWidth + node.depth! * _rowExtent + textPainter.width;

    var matchText = text.substring(
      activeMatch.start,
      activeMatch.start + activeMatch.length,
    );
    final textPainter2 = TextPainter(
      //TODO style
      text: TextSpan(text: matchText, style: widget.textStyle),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();
    final matchTextWidth = textPainter2.width;

    double? targetOffset;
    if (width < scrollController.offset) {
      // isOutOfViewLeft
      targetOffset = math.max(width - _matchHorizontalScrollSpace, 0.0);
    } else if (width + matchTextWidth >
        scrollController.offset + widget.width) {
      // isOutOfViewRight && !isOutOfViewLeft

      if (matchTextWidth > widget.width) {
        targetOffset = math.max(width - _matchHorizontalScrollSpace, 0.0);
      } else {
        targetOffset = math.min(
          width + matchTextWidth + _matchHorizontalScrollSpace - widget.width,
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
          treeNodeBuilder: _treeNodeBuilder,
          treeRowExtentBuilder: (node, dimensions) => _rowHeight,
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
            return _JsonViewerRowItem(
              node: node as TreeSliverNode<TreeNodeData>,
              theme: widget.colorTheme,
              searchMatches: _searchMatchesForLine(node),
            );
          },
        );
      },
    );
  }

  List<JsonViewFindMatch> _searchMatchesForLine(TreeSliverNode<Object?> node) {
    // TODO
    return widget.jsonViewerController.searchMatches.value
        .where((searchMatch) => searchMatch.ref == node)
        .toList();
  }
}

class _SizeUpdateContainer extends StatefulWidget {
  const _SizeUpdateContainer({
    super.key,

    required this.height,
    required this.maxWidthNotifier,
    required this.child,
  });

  final double height;
  final ValueNotifier<double> maxWidthNotifier;
  final Widget child;

  @override
  State<_SizeUpdateContainer> createState() => _SizeUpdateContainerState();
}

class _SizeUpdateContainerState extends State<_SizeUpdateContainer> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.maxWidthNotifier,
      builder: (context, child) {
        return SizedBox(
          width: widget.maxWidthNotifier.value,
          height: widget.height,
          child: widget.child,
        );
      },
    );
  }
}

class _JsonViewerRowItem extends StatelessWidget {
  const _JsonViewerRowItem({
    super.key,
    required this.theme,
    required this.node,
    required this.searchMatches,
  });

  final ColorTheme? theme;
  final TreeSliverNode<TreeNodeData> node;
  final List<JsonViewFindMatch> searchMatches;

  @override
  Widget build(BuildContext context) {
    var content = node.content;
    final bool isParentNode = node.children.isNotEmpty;

    final border = BorderSide(
      width: 1,
      color: theme?.indent ?? _defaultIndentColor,
    );

    var oriDepth = node.depth!;

    var indentDepth = oriDepth;
    if (content.end) {
      indentDepth -= 1;
    }
    List<Widget> widgets = [
      const SizedBox(height: _rowHeight, width: _prefixWidth),
    ];
    for (int i = 0; i < indentDepth; i++) {
      widgets.add(
        DecoratedBox(
          decoration: BoxDecoration(
            border: node.parent != null ? Border(left: border) : null,
          ),
          child: SizedBox(height: _rowHeight, width: _rowExtent),
        ),
      );
    }

    var spans = content.computeTextSpan(
      expanded: node.isExpanded,
      hasChild: node.children.isNotEmpty,
      indentDepth: indentDepth,
      theme: theme,
    );

    return Row(
      children: [
        ...widgets,
        if (isParentNode)
          GestureDetector(
            onTap: () {
              TreeSliverController.of(context).toggleNode(node);
            },
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: SizedBox.square(
                dimension: _iconBoxSize,
                child: Icon(
                  node.isExpanded ? Icons.remove : Icons.add,
                  size: _iconSize,
                ),
              ),
            ),
          ),
        if (isParentNode) const SizedBox(width: _iconAfterSpace),
        Text.rich(searchAwareLineContents(spans, context)),
      ],
    );
  }

  TextSpan searchAwareLineContents(
    List<InlineSpan> spans,
    BuildContext context,
  ) {
    if (searchMatches.isNotEmpty) {
      for (var match in searchMatches) {
        var matchColor =
            match.isActiveSearchMatch
                ? theme?.activeFindMatchBackground ?? Color(0xFFFF0000)
                : theme?.findMatchBackground ?? Color(0xFFBC3939);

        spans = _contentsWithMatch(spans, match, matchColor, context: context);
      }
    }
    return TextSpan(children: spans);
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
            ref: match.ref,
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

class MaxWidthFindData {
  int depth;
  bool expanded;
  TreeNodeData content;
  bool hasChild;

  MaxWidthFindData({
    required this.content,
    required this.depth,
    required this.expanded,
    required this.hasChild,
  });

  int length(int factor) {
    // indent + (name + ': ') + content + ','

    int length = depth * factor;

    var name = content.name;
    if (name != null) {
      length += name.length + ': '.length;
    }

    var parsedStart = content.parsedStart;
    if (expanded && parsedStart != null) {
      length += parsedStart.length;
    } else {
      length += content.text.length;
    }

    if (hasChild && !expanded && content.collapsedTail != null) {
      length += '...'.length;
      length += content.collapsedTail!.length;
    }

    if (content.comma && !expanded) {
      length += ','.length;
    }
    return length;
  }
}

MaxWidthFindData _findLongestText(TreeSliverNode<TreeNodeData> treeNode) {
  return _doFindLongestText(treeNode, 0);
}

MaxWidthFindData _doFindLongestText(
  TreeSliverNode<TreeNodeData> treeNode,
  int depth,
) {
  var content = treeNode.content;
  if (treeNode.children.isEmpty || !treeNode.isExpanded) {
    return MaxWidthFindData(
      content: content,
      depth: depth,
      expanded: false,
      hasChild: treeNode.children.isNotEmpty,
    );
  } else {
    MaxWidthFindData max = MaxWidthFindData(
      content: content,
      depth: depth,
      expanded: true,
      hasChild: treeNode.children.isNotEmpty,
    );
    for (var child in treeNode.children) {
      var childData = _doFindLongestText(child, depth + 1);
      if (childData.length(2) > max.length(2)) {
        max = childData;
      }
    }
    return max;
  }
}

JsonValueVM displayParse(JsonValue value) {
  switch (value) {
    case JsonNull():
      return JsonNullVM();
    case JsonBool():
      return JsonBoolVM(value.value);
    case JsonString():
      var text = value.value;

      JsonValueVM? jsonValue;
      if (text.length > 20 && (text[0] == '[' || text[0] == '{')) {
        try {
          var parsedValue = Parser.parse(text);
          jsonValue = displayParse(parsedValue);
        } catch (e) {}
      }

      return JsonStringVM(rawText: value.rawText, parsed: jsonValue);
    case JsonNumber():
      return JsonNumberVM(rawText: value.rawText, value: value.value);
    case JsonArray():
      var newElements = value.elements.map((e) => displayParse(e)).toList();
      return JsonArrayVM(elements: newElements);
    case NormalJsonObject():
      return displayParseNormalObject(value);
    case EnhancedJsonObject():
      return displayParseEnhancedObject(value);
  }
}

JsonObjectVM displayParseNormalObject(NormalJsonObject value) {
  LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> newMap = LinkedHashMap();
  value.entryMap.forEach((entryKey, entryValue) {
    var newKey = JsonObjectKeyStringVM(
      JsonStringVM(rawText: entryKey.value.rawText),
    );
    newMap[newKey] = displayParse(entryValue);
  });
  return NormalJsonObjectVM(entryMap: newMap);
}

JsonObjectVM displayParseEnhancedObject(EnhancedJsonObject value) {
  LinkedHashMap<JsonObjectKeyVM, JsonValueVM> newMap = LinkedHashMap();
  value.entryMap.forEach((entryKey, entryValue) {
    JsonObjectKeyVM newKey = switch (entryKey) {
      JsonObjectKeyString() =>
        JsonObjectKeyStringVM(JsonStringVM(rawText: entryKey.value.rawText))
            as JsonObjectKeyVM,
      JsonObjectKeyNumber() => JsonObjectKeyNumberVM(
        JsonNumberVM(
          rawText: entryKey.value.rawText,
          value: entryKey.value.value,
        ),
      ),
      JsonObjectKeyBool() => JsonObjectKeyBoolVM(
        JsonBoolVM(entryKey.value.value),
      ),
      JsonObjectKeyNull() => JsonObjectKeyNullVM(),
      JsonObjectKeyObject() => JsonObjectKeyObjectVM(
        displayParseObject(entryKey.value),
      ),
    };
    newMap[newKey] = displayParse(entryValue);
  });
  return EnhancedJsonObjectVM(entryMap: newMap);
}

JsonObjectVM displayParseObject(JsonObject value) {
  switch (value) {
    case NormalJsonObject():
      return displayParseNormalObject(value);
    case EnhancedJsonObject():
      return displayParseEnhancedObject(value);
  }
}

enum TreeNodeDataType {
  object,
  objectStart,
  objectEnd,
  array,
  arrayStart,
  arrayEnd,
  literalTrue,
  literalFalse,
  literalNull,
  string,
  number,
  error,
}

class TreeNodeData {
  final String text;
  final JsonValueVM? ref;
  final TreeNodeDataType type;
  final String? name;
  final String? collapsedTail;
  final String? parsedStart;
  final TreeNodeDataType? parsedType;
  final bool end;
  final bool comma;
  final bool collapsedComma;

  late String stringForFind;

  TreeNodeData(
    this.text, {
    this.ref,
    required this.type,
    this.name,
    this.collapsedTail,
    this.parsedStart,
    this.parsedType,
    this.end = false,
    this.comma = false,
    this.collapsedComma = false,
  }) {
    // TODO
    var span = TextSpan(
      children: computeTextSpan(
        expanded: true,
        hasChild: false,
        indentDepth: 0,
        theme: null,
      ),
    );
    stringForFind = span.toPlainText().toLowerCase();
  }

  List<InlineSpan> computeTextSpan({
    required bool expanded,
    required bool hasChild,
    required int indentDepth,
    required ColorTheme? theme,
    TextStyle? style,
  }) {
    var contentStyle = buildContentStyle(type, indentDepth, theme);
    List<InlineSpan> spans = [];
    if (name != null) {
      spans.add(TextSpan(text: name, style: TextStyle(color: theme?.key)));
      spans.add(TextSpan(text: ": ", style: buildStyle(theme?.colon)));
    }
    if (expanded && parsedStart != null) {
      var parsedContentStyle = buildContentStyle(
        parsedType!,
        indentDepth,
        theme,
      );
      spans.add(TextSpan(text: parsedStart, style: parsedContentStyle));
    } else {
      spans.add(TextSpan(text: text, style: contentStyle));
    }
    if (hasChild && !expanded && collapsedTail != null) {
      spans.add(TextSpan(text: '...'));
      spans.add(TextSpan(text: collapsedTail!, style: contentStyle));
    }
    if ((!expanded && comma) || (!expanded && collapsedComma)) {
      spans.add(TextSpan(text: ',', style: buildStyle(theme?.comma)));
    }
    return spans;
  }

  TextStyle? buildContentStyle(
    TreeNodeDataType type,
    int depth,
    ColorTheme? theme,
  ) {
    Color? color;
    if (type == TreeNodeDataType.string) {
      color = theme?.string;
    } else if (type == TreeNodeDataType.number) {
      color = theme?.number;
    } else if (type == TreeNodeDataType.literalTrue) {
      color = theme?.literal;
    } else if (type == TreeNodeDataType.literalFalse) {
      color = theme?.literal;
    } else if (type == TreeNodeDataType.literalNull) {
      color = theme?.literal;
    } else if (type == TreeNodeDataType.object ||
        type == TreeNodeDataType.objectStart ||
        type == TreeNodeDataType.objectEnd ||
        type == TreeNodeDataType.array ||
        type == TreeNodeDataType.arrayStart ||
        type == TreeNodeDataType.arrayEnd) {
      var brackets = theme?.brackets;
      if (brackets != null && brackets.isNotEmpty) {
        color = brackets[depth % brackets.length];
      }
    }
    return buildStyle(color);
  }

  TextStyle? buildStyle(Color? color) {
    if (color == null) {
      return null;
    }
    return TextStyle(color: color);
  }
}

TreeSliverNode<TreeNodeData> buildTreeNodes(
  JsonValueVM jsonValue, {
  bool defaultExpand = true,
}) {
  var builder = _TreeSliverBuilder(defaultExpand);
  return builder._doBuildTreeNodes(jsonValue);
}

class _TreeSliverBuilder {
  final bool _defaultExpand;

  _TreeSliverBuilder(this._defaultExpand);

  TreeSliverNode<TreeNodeData> _doBuildTreeNodes(
    JsonValueVM jsonValue, {
    String? prefix,
    bool comma = false,
  }) {
    return switch (jsonValue) {
      JsonNullVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type: TreeNodeDataType.literalNull,
          name: prefix,
          comma: comma,
        ),
      ),
      JsonStringVM() => _doBuildTreeNodeString(
        jsonValue,
        prefix: prefix,
        comma: comma,
      ),
      JsonBoolVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type:
              jsonValue.value
                  ? TreeNodeDataType.literalTrue
                  : TreeNodeDataType.literalFalse,
          name: prefix,
          comma: comma,
        ),
      ),
      JsonNumberVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type: TreeNodeDataType.number,
          name: prefix,
          comma: comma,
        ),
      ),
      JsonArrayVM() => _doBuildTreeNodeArray(
        jsonValue,
        comma: comma,
        prefix: prefix,
      ),
      NormalJsonObjectVM() => _doBuildTreeNodeNormalObject(
        jsonValue,
        comma: comma,
        prefix: prefix,
      ),
      EnhancedJsonObjectVM() => _doBuildTreeNodeEnhancedObject(
        jsonValue,
        comma: comma,
        prefix: prefix,
      ),
    };
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeString(
    JsonStringVM jsonValue, {
    String? prefix,
    bool comma = false,
  }) {
    List<TreeSliverNode<TreeNodeData>>? children;
    String? parsedStart;
    TreeNodeDataType? parsedType;
    var parsed = jsonValue.parsed;
    if (parsed != null) {
      switch (parsed) {
        case JsonArrayVM():
          children = _doBuildTreeNodeArrayElements(parsed.elements, comma);
          parsedStart = '[';
          parsedType = TreeNodeDataType.arrayStart;
          break;
        case NormalJsonObjectVM():
          children = _doBuildTreeNodeNormalObjectEntries(
            parsed.entryMap,
            comma,
          );
          parsedStart = '{';
          parsedType = TreeNodeDataType.objectStart;
          break;
        case EnhancedJsonObjectVM():
          children = _doBuildTreeNodeEnhancedObjectEntries(
            parsed.entryMap,
            comma,
          );
          parsedStart = '{';
          parsedType = TreeNodeDataType.objectStart;
          break;
        default:
          break;
      }
    }

    return TreeSliverNode(
      TreeNodeData(
        jsonValue.rawText,
        type: TreeNodeDataType.string,
        name: prefix,
        comma: comma,
        parsedStart: parsedStart,
        parsedType: parsedType,
      ),
      children: children,
    );
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeArray(
    JsonArrayVM jsonValue, {
    String? prefix,
    bool comma = false,
  }) {
    if (jsonValue.elements.isEmpty) {
      return TreeSliverNode(
        TreeNodeData(
          '[ ]',
          type: TreeNodeDataType.array,
          name: prefix,
          ref: jsonValue,
          comma: comma,
        ),
      );
    } else {
      var children = _doBuildTreeNodeArrayElements(jsonValue.elements, comma);

      return TreeSliverNode(
        TreeNodeData(
          '[',
          collapsedTail: ']',
          type: TreeNodeDataType.arrayStart,
          name: prefix,
          ref: jsonValue,
          collapsedComma: comma,
        ),
        children: children,
        expanded: _defaultExpand,
      );
    }
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeArrayElements(
    List<JsonValueVM> elements,
    bool comma,
  ) {
    List<TreeSliverNode<TreeNodeData>> children = [];
    int idx = 1;
    for (var element in elements) {
      children.add(_doBuildTreeNodes(element, comma: idx < elements.length));
      idx += 1;
    }
    children.add(
      TreeSliverNode(
        TreeNodeData(
          ']',
          type: TreeNodeDataType.arrayEnd,
          end: true,
          comma: comma,
        ),
      ),
    );
    return children;
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeNormalObject(
    NormalJsonObjectVM jsonValue, {
    String? prefix,
    bool comma = false,
  }) {
    if (jsonValue.entryMap.isEmpty) {
      return TreeSliverNode(
        TreeNodeData(
          '{ }',
          type: TreeNodeDataType.object,
          name: prefix,
          ref: jsonValue,
          comma: comma,
        ),
      );
    }

    var children = _doBuildTreeNodeNormalObjectEntries(
      jsonValue.entryMap,
      comma,
    );

    return TreeSliverNode(
      TreeNodeData(
        '{',
        collapsedTail: '}',
        type: TreeNodeDataType.objectStart,
        name: prefix,
        ref: jsonValue,
        collapsedComma: comma,
      ),
      children: children,
      expanded: _defaultExpand,
    );
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeNormalObjectEntries(
    LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> entryMap,
    bool comma,
  ) {
    List<TreeSliverNode<TreeNodeData>> children = [];
    int idx = 1;
    for (var entry in entryMap.entries) {
      var key = entry.key.value.rawText;
      children.add(
        _doBuildTreeNodes(
          entry.value,
          prefix: key,
          comma: idx < entryMap.length,
        ),
      );
      idx += 1;
    }
    children.add(
      TreeSliverNode(
        TreeNodeData(
          '}',
          type: TreeNodeDataType.objectEnd,
          end: true,
          comma: comma,
        ),
      ),
    );
    return children;
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeEnhancedObject(
    EnhancedJsonObjectVM jsonValue, {
    String? prefix,
    bool comma = false,
  }) {
    if (jsonValue.entryMap.isEmpty) {
      return TreeSliverNode(
        TreeNodeData(
          '{ }',
          type: TreeNodeDataType.object,
          name: prefix,
          ref: jsonValue,
          comma: comma,
        ),
      );
    }

    var children = _doBuildTreeNodeEnhancedObjectEntries(
      jsonValue.entryMap,
      comma,
    );

    return TreeSliverNode(
      TreeNodeData(
        '{',
        collapsedTail: '}',
        type: TreeNodeDataType.objectStart,
        name: prefix,
        ref: jsonValue,
        collapsedComma: comma,
      ),
      children: children,
      expanded: _defaultExpand,
    );
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeEnhancedObjectEntries(
    LinkedHashMap<JsonObjectKeyVM, JsonValueVM> entryMap,
    bool comma,
  ) {
    List<TreeSliverNode<TreeNodeData>> children = [];
    int idx = 1;
    for (var entry in entryMap.entries) {
      var entryKey = entry.key;

      var newKey = _toStringKey(entryKey);

      children.add(
        _doBuildTreeNodes(
          entry.value,
          prefix: newKey,
          comma: idx < entryMap.length,
        ),
      );
      idx += 1;
    }
    children.add(
      TreeSliverNode(
        TreeNodeData(
          '}',
          type: TreeNodeDataType.objectEnd,
          end: true,
          comma: comma,
        ),
      ),
    );
    return children;
  }

  String _toStringKey(JsonObjectKeyVM entryKey) {
    var buff = StringBuffer();
    var helper = ToStringHelper(whitespace: true);
    helper._toStringKeyX(buff, entryKey);
    return buff.toString();
  }
}

class ToStringHelper {
  bool whitespace;
  bool deepParse;
  StringBuffer buffer = StringBuffer();

  ToStringHelper({required this.whitespace, this.deepParse = false});

  void _toStringKeyX(StringBuffer buffer, JsonObjectKeyVM entryKey) {
    switch (entryKey) {
      case JsonObjectKeyNumberVM():
        buffer.write(entryKey.value.rawText);
        break;
      case JsonObjectKeyBoolVM():
        buffer.write(entryKey.value.rawText);
        break;
      case JsonObjectKeyNullVM():
        buffer.write('null');
        break;
      case JsonObjectKeyObjectVM():
        toJsonString(buffer, entryKey.value);
        break;
    }
  }

  void toJsonString(StringBuffer buffer, JsonValueVM jsonValue) {
    switch (jsonValue) {
      case JsonNullVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonStringVM():
        var parsed = jsonValue.parsed;
        if (parsed != null && deepParse) {
          toJsonString(buffer, parsed);
        } else {
          buffer.write(jsonValue.rawText);
        }
        break;
      case JsonBoolVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonNumberVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonArrayVM():
        buffer.write('[');
        int idx = 1;
        for (var element in jsonValue.elements) {
          toJsonString(buffer, element);
          if (idx < jsonValue.elements.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write(']');
        break;
      case NormalJsonObjectVM():
        buffer.write('{');
        int idx = 1;
        for (var entry in jsonValue.entryMap.entries) {
          buffer.write(entry.key.value.rawText);
          buffer.write(':');
          if (whitespace) {
            buffer.write(' ');
          }
          toJsonString(buffer, entry.value);
          if (idx < jsonValue.entryMap.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write('}');
        break;
      case EnhancedJsonObjectVM():
        buffer.write('{');
        int idx = 1;
        for (var entry in jsonValue.entryMap.entries) {
          _toStringKeyX(buffer, entry.key);
          // buffer.write(entry.key.value.rawText);
          buffer.write(':');
          if (whitespace) {
            buffer.write(' ');
          }
          toJsonString(buffer, entry.value);
          if (idx < jsonValue.entryMap.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write('}');
    }
  }
}
