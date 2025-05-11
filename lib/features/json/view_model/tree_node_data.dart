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

  bool get isEnd =>
      type == TreeNodeDataType.objectEnd || type == TreeNodeDataType.arrayEnd;

  const TreeNodeData(
    this.text, {
    this.ref,
    required this.type,
    this.name,
    this.comma = false,
    this.tail,
    required this.isNameAllAscii,
    required this.isTextAllAscii,
  });
}

TreeSliverNode<TreeNodeData> buildTreeNodes(
  JsonValueVM jsonValue, {
  bool defaultExpand = true,
}) {
  final builder = _TreeSliverBuilder(defaultExpand);
  return builder._doBuildTreeNodes(jsonValue);
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
      if (objectKey is JsonObjectKeyStringVM) {
        keyAllAscii = objectKey.value.allAscii;
        keyString = objectKey.value.rawText;
      } else {
        throw Exception('Not supported');
      }
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
        ),
        children: _emptyArray,
      ),
      JsonStringVM() => TreeSliverNode(
        TreeNodeData(
          jsonValue.rawText,
          type: TreeNodeDataType.string,
          name: keyString,
          comma: comma,
          isNameAllAscii: keyAllAscii,
          isTextAllAscii: jsonValue.allAscii,
        ),
        children: _emptyArray,
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
    };
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
}
