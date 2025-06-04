class TreePath<T> {
  final TreePath<T>? prev;
  final T data;

  const TreePath._({required this.prev, required this.data});

  factory TreePath.root(T data) {
    return TreePath._(prev: null, data: data);
  }

  factory TreePath.node({required TreePath<T> prev, required T data}) {
    return TreePath._(prev: prev, data: data);
  }

  void invokeFromRoot(void Function(T data) func) {
    _innerInvokeReverse(func);
  }

  void _innerInvokeReverse(void Function(T data) func) {
    final prevTmp = prev;
    if (prevTmp != null) {
      prevTmp._innerInvokeReverse(func);
    }
    func(data);
  }
}
