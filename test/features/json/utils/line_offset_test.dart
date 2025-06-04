import 'package:dev_tools/features/json/model/tree_path.dart';
import 'package:dev_tools/features/json/utils/sliver_tree_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /**
      01| root[
      02|     a-1
      03|     a-2[
      04|         b1-1
      05|         b1-2[
      06|             nested-1
      07|             nested-2
      08|         b1-3]
      09|     a-3]
      10|     a-4[    fold-1,fold-2,fold-3   a-5]
      11|     a-6
      12|     a-7
      13|         b2-1
      14|         b2-2
      15|         b2-3
      16|         b2-4
      17|     a-8
      18| root-end]
   **/
  final TreeSliverNode<String> tree = TreeSliverNode(
    'root',
    expanded: true,
    children: [
      TreeSliverNode('a-1'),
      TreeSliverNode(
        'a-2',
        expanded: true,
        children: [
          TreeSliverNode('b1-1'),
          TreeSliverNode(
            'b1-2',
            expanded: true,
            children: [
              TreeSliverNode('nested-1'),
              TreeSliverNode('nested-2'),
              TreeSliverNode('b1-3'),
            ],
          ),
          TreeSliverNode('a-3'),
        ],
      ),
      TreeSliverNode(
        'a-4',
        expanded: false,
        children: [
          TreeSliverNode('fold-1'),
          TreeSliverNode('fold-2'),
          TreeSliverNode('fold-3'),
          TreeSliverNode('a-5'),
        ],
      ),
      TreeSliverNode('a-6'),
      TreeSliverNode(
        'a-7',
        expanded: true,
        children: [
          TreeSliverNode('b2-1'),
          TreeSliverNode('b2-2'),
          TreeSliverNode('b2-3'),
          TreeSliverNode('b2-4'),
          TreeSliverNode('a-8'),
        ],
      ),
      TreeSliverNode('root-end'),
    ],
  );

  final testcases = [
    ('root', 'root', 1),
    ('a-1', 'a-1', 2),
    ('nested-1', 'nested-1', 6),
    ('a-4', 'a-4', 10),
    ('a-7', 'a-7', 12),
    ('b2-2', 'b2-2', 14),
    ('b2-4', 'b2-4', 16),
    ('root-end', 'root-end', 18),
  ];

  group('Test LineOffsetCompute', () {
    for (final testcase in testcases) {
      test(testcase.$1, () {
        final path = _searchTree(tree, testcase.$2)!;
        final lines = computeOffsetLines(path);
        expect(lines, testcase.$3);
      });
    }
  });
}

TreePath<TreeSliverNode<String>>? _searchTree(
  TreeSliverNode<String> tree,
  String text,
) {
  return _doSearchTree(tree, TreePath.root(tree), text);
}

TreePath<TreeSliverNode<String>>? _doSearchTree(
  TreeSliverNode<String> tree,
  TreePath<TreeSliverNode<String>> path,
  String text,
) {
  if (tree.content == text) {
    return path;
  } else {
    for (final child in tree.children) {
      final result = _doSearchTree(
        child,
        TreePath.node(prev: path, data: child),
        text,
      );
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
