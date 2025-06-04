import 'package:flutter/widgets.dart';

import '../model/tree_path.dart';

int computeOffsetLines<T>(TreePath<TreeSliverNode<T>> path) {
  final prePath = path.prev;
  if (prePath == null) {
    return 1;
  }

  final currentNode = path.data;
  final parentNode = prePath.data;
  int count = 0;
  for (final child in parentNode.children) {
    if (identical(child, currentNode)) {
      count += 1 + computeOffsetLines(prePath);
      break;
    } else {
      count += _countNodeLines(child);
    }
  }
  return count;
}

int _countNodeLines<T>(TreeSliverNode<T> nodeTree) {
  if (nodeTree.isExpanded) {
    var count = 1;
    for (final child in nodeTree.children) {
      count += _countNodeLines(child);
    }
    return count;
  } else {
    return 1;
  }
}
