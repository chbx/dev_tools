import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'json_value_vm.dart';

const _emptyArray = <TreeSliverNode<TreeNodeData>>[];

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
}

class TreeNodeData {
  final String text;
  final JsonValueVM? ref;
  final TreeNodeDataType type;
  final String? name;
  final bool isNameAllAscii;
  final bool comma;
  final TreeNodeData? tail;
  final bool isTextAllAscii;
  final String? parsedStart;
  final TreeNodeDataType? parsedType;
  final String? shortString;
  final String? hintString;
  bool showRef;

  // TODO 增加展开 & 折叠 默认值

  bool get isEnd =>
      type == TreeNodeDataType.objectEnd || type == TreeNodeDataType.arrayEnd;

  TreeNodeData(
    this.text, {
    this.ref,
    required this.type,
    this.name,
    this.comma = false,
    this.tail,
    required this.isNameAllAscii,
    required this.isTextAllAscii,
    this.parsedStart,
    this.parsedType,
    this.shortString,
    this.hintString,
  }) : showRef = false;

  String contactString() {
    String result;
    if (name != null) {
      result = '$name: $text';
    } else {
      result = text;
    }
    if (comma) {
      result += ',';
    }
    return result;
  }
}

TreeSliverNode<TreeNodeData> buildTreeNodes(
  JsonValueVM jsonValue, {
  bool defaultExpand = true,
}) {
  final builder = _TreeSliverBuilder(defaultExpand);
  return builder._doBuildTreeNodes(jsonValue);
}

TreeSliverNode<TreeNodeData> rebuildSliverTree(
  TreeSliverNode<TreeNodeData> tree, {
  required bool defaultExpand,
}) {
  final List<TreeSliverNode<TreeNodeData>> children;
  if (tree.children.isNotEmpty) {
    children =
        tree.children
            .map((c) => rebuildSliverTree(c, defaultExpand: defaultExpand))
            .toList();
  } else {
    children = tree.children;
  }
  bool expand = defaultExpand;
  if (defaultExpand) {
    if (!tree.isExpanded) {
      if (tree.content.parsedStart != null) {
        expand = false;
      } else if (tree.content.shortString != null) {
        expand = false;
      }
    }
  }
  return TreeSliverNode(tree.content, children: children, expanded: expand);
}

class _TreeSliverBuilder {
  final bool _defaultExpand;

  _TreeSliverBuilder(this._defaultExpand);

  TreeSliverNode<TreeNodeData> _doBuildTreeNodes(
    JsonValueVM jsonValue, {
    JsonObjectKeyVM? objectKey,
    bool comma = false,
  }) {
    bool keyAllAscii;
    String? keyString;
    if (objectKey != null) {
      final result = _toStringKey(objectKey);
      keyAllAscii = result.keyAllAscii;
      keyString = result.keyString;
    } else {
      keyAllAscii = true;
    }

    return switch (jsonValue) {
      JsonNullVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type: TreeNodeDataType.literalNull,
          name: keyString,
          comma: comma,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: _emptyArray,
      ),
      JsonBoolVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type:
              jsonValue.value
                  ? TreeNodeDataType.literalTrue
                  : TreeNodeDataType.literalFalse,
          name: keyString,
          comma: comma,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: _emptyArray,
      ),
      JsonNumberVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type: TreeNodeDataType.number,
          name: keyString,
          comma: comma,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
          hintString: jsonValue.dateHint,
        ),
        children: _emptyArray,
      ),
      JsonStringVM() => _doBuildTreeNodeString(
        jsonValue,
        comma: comma,
        prefix: keyString,
        keyAllAscii: keyAllAscii,
      ),
      JsonArrayVM() => _doBuildTreeNodeArray(
        jsonValue,
        comma: comma,
        prefix: keyString,
        keyAllAscii: keyAllAscii,
      ),
      NormalJsonObjectVM() => _doBuildTreeNodeNormalObject(
        jsonValue,
        comma: comma,
        prefix: keyString,
        keyAllAscii: keyAllAscii,
      ),
      ExtendedJsonObjectVM() => _doBuildTreeNodeExtendedObject(
        jsonValue,
        comma: comma,
        prefix: keyString,
        keyAllAscii: keyAllAscii,
      ),
    };
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeString(
    JsonStringVM jsonValue, {
    String? prefix,
    required bool keyAllAscii,
    bool comma = false,
  }) {
    List<TreeSliverNode<TreeNodeData>> children = _emptyArray;
    String? parsedStart;
    TreeNodeDataType? parsedType;
    final parsed = jsonValue.parsed;
    if (parsed != null) {
      switch (parsed) {
        case JsonArrayVM():
          children = _doBuildTreeNodeArrayElements(parsed.elements);
          final tail = TreeNodeData(
            ']',
            type: TreeNodeDataType.arrayEnd,
            comma: comma,
            isNameAllAscii: true,
            isTextAllAscii: true,
          );
          children.add(TreeSliverNode(tail, children: _emptyArray));
          parsedStart = '[';
          parsedType = TreeNodeDataType.arrayStart;
          break;
        case NormalJsonObjectVM():
          children = _doBuildTreeNodeNormalObjectEntries(parsed.entryMap);
          final tail = TreeNodeData(
            '}',
            type: TreeNodeDataType.objectEnd,
            comma: comma,
            isNameAllAscii: true,
            isTextAllAscii: true,
          );
          children.add(TreeSliverNode(tail, children: _emptyArray));
          parsedStart = '{';
          parsedType = TreeNodeDataType.objectStart;
          break;
        case ExtendedJsonObjectVM():
          children = _doBuildTreeNodeExtendedObjectEntries(parsed.entryMap);
          final tail = TreeNodeData(
            '}',
            type: TreeNodeDataType.objectEnd,
            comma: comma,
            isNameAllAscii: true,
            isTextAllAscii: true,
          );
          children.add(TreeSliverNode(tail, children: _emptyArray));
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
        isNameAllAscii: keyAllAscii,
        // TODO
        isTextAllAscii: false,
      ),
      children: children,
    );
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeArray(
    JsonArrayVM jsonValue, {
    String? prefix,
    required bool keyAllAscii,
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
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: _emptyArray,
      );
    } else {
      final children = _doBuildTreeNodeArrayElements(jsonValue.elements);
      final tail = TreeNodeData(
        ']',
        type: TreeNodeDataType.arrayEnd,
        comma: comma,
        isNameAllAscii: true,
        isTextAllAscii: true,
      );
      children.add(TreeSliverNode(tail, children: _emptyArray));

      return TreeSliverNode(
        TreeNodeData(
          '[',
          type: TreeNodeDataType.arrayStart,
          name: prefix,
          ref: jsonValue,
          tail: tail,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: children,
        expanded: _defaultExpand,
      );
    }
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeArrayElements(
    List<JsonValueVM> elements,
  ) {
    final children = <TreeSliverNode<TreeNodeData>>[];
    int idx = 1;
    for (final element in elements) {
      children.add(_doBuildTreeNodes(element, comma: idx < elements.length));
      idx += 1;
    }
    return children;
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeNormalObject(
    NormalJsonObjectVM jsonValue, {
    String? prefix,
    required bool keyAllAscii,
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
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: _emptyArray,
      );
    }

    final children = _doBuildTreeNodeNormalObjectEntries(jsonValue.entryMap);
    final tail = TreeNodeData(
      '}',
      type: TreeNodeDataType.objectEnd,
      comma: comma,
      isNameAllAscii: true,
      isTextAllAscii: true,
    );
    children.add(TreeSliverNode(tail, children: _emptyArray));

    final shortString = jsonValue.shortString;
    return TreeSliverNode(
      TreeNodeData(
        '{',
        type: TreeNodeDataType.objectStart,
        name: prefix,
        ref: jsonValue,
        tail: tail,
        isNameAllAscii: keyAllAscii,
        isTextAllAscii: true,
        shortString: shortString,
      ),
      children: children,
      expanded: _defaultExpand && shortString == null,
    );
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeNormalObjectEntries(
    LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> entryMap,
  ) {
    final children = <TreeSliverNode<TreeNodeData>>[];
    int idx = 1;
    for (final entry in entryMap.entries) {
      children.add(
        _doBuildTreeNodes(
          entry.value,
          objectKey: entry.key,
          comma: idx < entryMap.length,
        ),
      );
      idx += 1;
    }

    return children;
  }

  TreeSliverNode<TreeNodeData> _doBuildTreeNodeExtendedObject(
    ExtendedJsonObjectVM jsonValue, {
    String? prefix,
    bool comma = false,
    required bool keyAllAscii,
  }) {
    if (jsonValue.entryMap.isEmpty) {
      return TreeSliverNode(
        TreeNodeData(
          '{ }',
          type: TreeNodeDataType.object,
          name: prefix,
          ref: jsonValue,
          comma: comma,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: true,
        ),
        children: _emptyArray,
      );
    }

    final children = _doBuildTreeNodeExtendedObjectEntries(jsonValue.entryMap);
    final tail = TreeNodeData(
      '}',
      type: TreeNodeDataType.objectEnd,
      comma: comma,
      isNameAllAscii: true,
      isTextAllAscii: true,
    );
    children.add(TreeSliverNode(tail, children: _emptyArray));

    return TreeSliverNode(
      TreeNodeData(
        '{',
        type: TreeNodeDataType.objectStart,
        name: prefix,
        ref: jsonValue,
        tail: tail,
        isNameAllAscii: keyAllAscii,
        isTextAllAscii: true,
      ),
      children: children,
      expanded: _defaultExpand,
    );
  }

  List<TreeSliverNode<TreeNodeData>> _doBuildTreeNodeExtendedObjectEntries(
    LinkedHashMap<JsonObjectKeyVM, JsonValueVM> entryMap,
  ) {
    final children = <TreeSliverNode<TreeNodeData>>[];
    int idx = 1;
    for (final entry in entryMap.entries) {
      final entryKey = entry.key;
      children.add(
        _doBuildTreeNodes(
          entry.value,
          objectKey: entryKey,
          comma: idx < entryMap.length,
        ),
      );
      idx += 1;
    }
    return children;
  }
}

({bool keyAllAscii, String keyString}) _toStringKey(JsonObjectKeyVM objectKey) {
  // todo objectKey - 扩展key类型展示不同样式
  final keyInfo = switch (objectKey) {
    JsonObjectKeyStringVM() => (
      objectKey.value.allAscii,
      objectKey.value.rawText,
    ),
    JsonObjectKeyNumberVM() => (true, objectKey.value.rawText),
    JsonObjectKeyBoolVM() => (true, objectKey.value.rawText),
    JsonObjectKeyNullVM() => (true, 'null'),
    JsonObjectKeyObjectVM() => (
      // TODO 对象作为key，是否全部ascii字符
      false,
      JsonValueVM.toJsonString(objectKey.value),
    ),
  };
  return (keyAllAscii: keyInfo.$1, keyString: keyInfo.$2);
}
