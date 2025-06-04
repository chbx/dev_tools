import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/widgets/search/search_controller.dart';
import '../core/json_parser.dart';
import '../core/json_parser_options.dart';
import '../model/tree_path.dart';
import '../model/viewer_options.dart';
import '../service/display_opt.dart';
import '../view_model/json_value_vm.dart';
import '../view_model/tree_node_data.dart';

class JsonViewerController with SearchControllerMixin<JsonViewFindMatch> {
  JsonViewerController({
    String text = '',
    this.options = const JsonViewerOptions(),
  }) {
    this.text = text;
    initSearch();
  }

  void dispose() {
    _viewDataNotifier.dispose();
    _showSearchField.dispose();
    disposeSearch();
  }

  final JsonViewerOptions options;

  ValueListenable<JsonViewerData> get viewDataNotifier => _viewDataNotifier;
  final _viewDataNotifier = ValueNotifier(JsonViewerData(text: ''));

  set text(String text) {
    if (text == _viewDataNotifier.value.text) {
      return;
    }
    // TODO 异步
    final viewData = _parse(text);
    _viewDataNotifier.value = viewData;

    refreshSearchMatches();
  }

  JsonViewerData _parse(String text) {
    JsonValueVM? jsonValueVM;
    String? errorMessage;
    try {
      if (text.isNotEmpty) {
        final jsonValue = JsonParser.parse(
          text,
          options: JsonParseOptions.loose(
            backSlashEscapeType:
                BackSlashEscapeType.onlyBackSlashAndDoubleQuote,
          ),
        );
        jsonValueVM = JsonValueVM.from(jsonValue);
        JsonValueDisplayOptimizer(options: options).processTree(jsonValueVM);
      }
    } catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      errorMessage = '解析异常';
    }

    if (options.autoParsedRootString &&
        jsonValueVM is JsonStringVM &&
        jsonValueVM.parsed != null) {
      jsonValueVM = jsonValueVM.parsed!;
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

  String? getTextContent() {
    final jsonValue = _viewDataNotifier.value.jsonValueVM;
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
    final previousValue = _viewDataNotifier.value;
    final previousTreeNode = previousValue.treeNode;
    if (previousTreeNode != null) {
      final newTreeNode = rebuildSliverTree(
        previousTreeNode,
        defaultExpand: defaultExpand,
      );
      _viewDataNotifier.value = JsonViewerData(
        text: previousValue.text,
        jsonValueVM: previousValue.jsonValueVM,
        treeNode: newTreeNode,
        errorMessage: previousValue.errorMessage,
      );

      _rebuildSearchMatches(newTreeNode);
    }
  }

  void _rebuildSearchMatches(TreeSliverNode<TreeNodeData> treeNode) {
    final matches = searchMatches.value;
    final newMatches = <JsonViewFindMatch>[];
    final pathCache =
        <
          TreeSliverNode<TreeNodeData>,
          TreePath<TreeSliverNode<TreeNodeData>>
        >{};
    for (final searchMath in matches) {
      final newPath = _buildSamePath(searchMath.path, treeNode, pathCache);
      newMatches.add(searchMath.withPath(newPath));
    }
    updateSearchMatchesSilently(newMatches);
  }

  TreePath<TreeSliverNode<TreeNodeData>> _buildSamePath(
    TreePath<TreeSliverNode<TreeNodeData>> previousPath,
    TreeSliverNode<TreeNodeData> treeNode,
    Map<TreeSliverNode<TreeNodeData>, TreePath<TreeSliverNode<TreeNodeData>>>
    pathCache,
  ) {
    final cachedPath = pathCache[previousPath.data];
    if (cachedPath != null) {
      return cachedPath;
    }

    TreePath<TreeSliverNode<TreeNodeData>> newPath;
    if (previousPath.prev == null) {
      newPath = TreePath.root(treeNode);
    } else {
      final prevParPath = previousPath.prev!;
      final newParentPath = _buildSamePath(prevParPath, treeNode, pathCache);
      final index = prevParPath.data.children.indexOf(previousPath.data);
      assert(index >= 0);
      final newNode = newParentPath.data.children[index];
      newPath = TreePath.node(prev: newParentPath, data: newNode);
    }
    pathCache[previousPath.data] = newPath;
    return newPath;
  }

  ValueListenable<bool> get showSearchField => _showSearchField;
  final _showSearchField = ValueNotifier<bool>(false);

  void showOrFocusSearchField() {
    final previousValue = _showSearchField.value;
    if (!previousValue) {
      _showSearchField.value = true;
      resetSearch();
    }
    searchFieldFocusNode?.requestFocus();
  }

  void closeSearchField() {
    final previousValue = _showSearchField.value;
    if (!previousValue) {
      return;
    }
    _showSearchField.value = false;
  }

  @override
  List<JsonViewFindMatch> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) {
    final treeNode = _viewDataNotifier.value.treeNode;

    if (treeNode == null) {
      return [];
    }

    search = search.toLowerCase();

    final allMatches = <JsonViewFindMatch>[];
    if (searchPreviousMatches) {
      final previousMatches = searchMatches.value;

      final searchedNodes = HashSet<TreeSliverNode<TreeNodeData>>();
      for (final previousMatch in previousMatches) {
        final notExist = searchedNodes.add(previousMatch.path.data);
        if (notExist) {
          _searchNode(previousMatch.path, search, allMatches);
        }
      }
    } else {
      _searchTree(treeNode, TreePath.root(treeNode), search, allMatches);
    }

    return allMatches;
  }

  void _searchTree(
    TreeSliverNode<TreeNodeData> node,
    TreePath<TreeSliverNode<TreeNodeData>> path,
    String search,
    List<JsonViewFindMatch> allMatches,
  ) {
    _searchNode(path, search, allMatches);
    for (final child in node.children) {
      _searchTree(
        child,
        TreePath.node(prev: path, data: child),
        search,
        allMatches,
      );
    }
  }

  void _searchNode(
    TreePath<TreeSliverNode<TreeNodeData>> path,
    String search,
    List<JsonViewFindMatch> allMatches,
  ) {
    final nodeData = path.data.content;
    final name = nodeData.name;
    final nameLen = name?.length ?? 0;

    if (!options.searchNestedRawString &&
        name == null &&
        nodeData.parsedStart != null) {
      return;
    }

    String text = nodeData.contactString();
    text = text.toLowerCase();

    final matches = search.allMatches(text);
    for (final match in matches) {
      if (!options.searchNestedRawString && nodeData.parsedStart != null) {
        if (match.start > nameLen) {
          return;
        }
      }

      allMatches.add(
        JsonViewFindMatch(start: match.start, end: match.end, path: path),
      );
    }
  }

  @override
  void onMatchChanged(int index, bool fromNavigation) {}
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

class JsonViewFindMatch with SearchableDataMixin {
  final TreePath<TreeSliverNode<TreeNodeData>> path;
  final int start;
  final int end;
  final int length;

  JsonViewFindMatch({
    required this.path,
    required this.start,
    required this.end,
  }) : length = end - start;

  JsonViewFindMatch withPath(TreePath<TreeSliverNode<TreeNodeData>> newPath) {
    return JsonViewFindMatch(start: start, end: end, path: newPath);
  }
}
