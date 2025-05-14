_TreeSliverState#collapseAll reversed 应删除
toggleNode校验`assert(_activeNodes.contains(node))`，应该从底部叶子节点关闭，
_collapseAll的遍历方式处理后，按顺序就是叶子节点到根结点，不用再反序
```dart
void collapseAll() {
    final List<TreeSliverNode<T>> activeNodesToCollapse = <TreeSliverNode<T>>[];
    _collapseAll(widget.tree, activeNodesToCollapse);
    activeNodesToCollapse.reversed.forEach(toggleNode);
}
```


```dart
// $flutter/packages/flutter/lib/src/rendering/paragraph.dart:3534
void paint(PaintingContext context, Offset offset) {
  for (final TextBox textBox in paragraph.getBoxesForSelection(selection,
      boxHeightStyle: ui.BoxHeightStyle.max)) {
    context.canvas.drawRect(textBox.toRect().shift(offset), selectionPaint);
  }
}
```
