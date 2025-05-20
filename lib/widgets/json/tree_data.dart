import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'model.dart';
import 'style.dart';

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
  final String? shortString;
  final String? hint;

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
    this.shortString,
    this.hint,
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
      if (shortString == null) {
        spans.add(
          TextSpan(text: '...', style: TextStyle(color: theme?.collapse)),
        );
      } else {
        spans.add(
          TextSpan(
            text: ' $shortString ',
            style: TextStyle(color: theme?.shortString),
          ),
        );
      }
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
          hint: jsonValue.dateHint,
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

    var shortString = jsonValue.shortString;

    return TreeSliverNode(
      TreeNodeData(
        '{',
        collapsedTail: '}',
        type: TreeNodeDataType.objectStart,
        name: prefix,
        ref: jsonValue,
        shortString: shortString,
        collapsedComma: comma,
      ),
      children: children,
      expanded: _defaultExpand && shortString == null,
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
    helper.toStringKey(buff, entryKey);
    return buff.toString();
  }
}
