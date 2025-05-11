import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'json_view_model.dart';
import 'parser/parser.dart';

const double _prefixWidth = 28;
const double _rowExtent = 24.0;
const double _rowHeight = 24.0;

const double _iconSize = 12;
const double _iconBoxSize = 16;
const double _iconAfterSpace = 4;

class ColorTheme {
  final Color? key;
  final Color? string;
  final Color? literal;
  final Color? number;
  final List<Color>? brackets;
  final Color? colon;
  final Color? comma;
  final Color? indent;

  const ColorTheme({
    this.key,
    this.string,
    this.literal,
    this.number,
    this.brackets,
    this.colon,
    this.comma,
    this.indent,
  });
}

const Color _defaultIndentColor = Color(0xFFd3d3d3);
const ColorTheme defaultTheme = ColorTheme(
  key: Color(0xFF0451a5),
  string: Color(0xFFa31515),
  literal: Color(0xFF0000ff),
  number: Color(0xFF098658),
  brackets: [Color(0xFF0431fa), Color(0xFF319331), Color(0xFF7b3814)],
  colon: Color(0xFF3b3b3b),
  comma: Color(0xFF3b3b3b),
  indent: _defaultIndentColor,
);

class JsonViewerController {
  _JsonViewerState? _state;

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
        });
      }
    }
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
            return _JsonViewerRowItem(
              node: node as TreeSliverNode<TreeNodeData>,
              theme: widget.colorTheme,
            );
          },
          treeRowExtentBuilder: (node, dimensions) => _rowHeight,
          toggleAnimationStyle: AnimationStyle.noAnimation,
          indentation: TreeSliverIndentationType.none,
          onNodeToggle: widget.onNodeToggle,
        ),
      ],
    );
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
  });

  final ColorTheme? theme;
  final TreeSliverNode<TreeNodeData> node;

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
        Text.rich(TextSpan(children: spans)),
      ],
    );
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

  const TreeNodeData(
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
  });

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
