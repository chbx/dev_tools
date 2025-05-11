import 'package:flutter/widgets.dart';

import '../core/json_parser.dart';
import '../core/json_parser_options.dart';
import '../view_model/json_value_vm.dart';
import '../view_model/tree_node_data.dart';

class JsonViewerController {
  JsonViewerController({String text = ''}) {
    this.text = text;
  }

  void dispose() {
    viewDataNotifier.dispose();
  }

  final viewDataNotifier = ValueNotifier(JsonViewerData(text: ''));

  set text(String text) {
    if (text == viewDataNotifier.value.text) {
      return;
    }
    // TODO 异步
    final viewData = _parse(text);
    viewDataNotifier.value = viewData;
  }

  String? getTextContent() {
    final jsonValue = viewDataNotifier.value.jsonValueVM;
    if (jsonValue == null) {
      return null;
    }
    return JsonValueVM.toJsonString(jsonValue);
  }

  void collapseAll() {
    // treeSliverController.collapseAll() 当数据量很大时有性能问题
    _rebuildViewData(defaultExpand: false);
  }

  void expandAll() {
    _rebuildViewData(defaultExpand: true);
  }

  void _rebuildViewData({required bool defaultExpand}) {
    final oldValue = viewDataNotifier.value;
    final oldTreeNode = oldValue.treeNode;
    if (oldTreeNode != null) {
      final oldValue = viewDataNotifier.value;
      viewDataNotifier.value = JsonViewerData(
        text: oldValue.text,
        jsonValueVM: oldValue.jsonValueVM,
        treeNode: _rebuildSliverTree(oldTreeNode, defaultExpand: defaultExpand),
        errorMessage: oldValue.errorMessage,
      );
    }
  }

  TreeSliverNode<TreeNodeData> _rebuildSliverTree(
    TreeSliverNode<TreeNodeData> tree, {
    required bool defaultExpand,
  }) {
    final List<TreeSliverNode<TreeNodeData>> children;
    if (tree.children.isNotEmpty) {
      children =
          tree.children
              .map((c) => _rebuildSliverTree(c, defaultExpand: defaultExpand))
              .toList();
    } else {
      children = tree.children;
    }
    return TreeSliverNode(
      tree.content,
      children: children,
      expanded: defaultExpand,
    );
  }
}

JsonViewerData _parse(String text) {
  JsonValueVM? jsonValueVM;
  String? errorMessage;
  try {
    if (text.isNotEmpty) {
      final jsonValue = JsonParser.parse(
        text,
        options: JsonParseOptions.loose(
          backSlashEscapeType: BackSlashEscapeType.onlyBackSlashAndDoubleQuote,
        ),
      );
      jsonValueVM = JsonValueVM.from(jsonValue);
    }
  } catch (e, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: stackTrace),
    );
    errorMessage = '解析异常';
  }

  TreeSliverNode<TreeNodeData>? treeNode;
  if (jsonValueVM != null) {
    treeNode = buildTreeNodes(jsonValueVM);
  }

  final viewData = JsonViewerData(
    text: text,
    jsonValueVM: jsonValueVM,
    treeNode: treeNode,
    errorMessage: errorMessage,
  );

  return viewData;
}

class JsonViewerData {
  final String text;
  final JsonValueVM? jsonValueVM;
  final TreeSliverNode<TreeNodeData>? treeNode;
  final String? errorMessage;

  const JsonViewerData({
    required this.text,
    this.jsonValueVM,
    this.treeNode,
    this.errorMessage,
  });
}
