class StringScanner {
  final String string;

  int get position => _position;
  int _position = 0;

  bool get isDone => position >= string.length;

  StringScanner(this.string);

  int get() {
    return string.codeUnitAt(_position);
  }

  void consume() {
    _position++;
  }

  bool hasMore(int count) {
    return position + count <= string.length;
  }

  void forward(int step) {
    _position += step;
  }

  String substring(int start, [int? end]) {
    end ??= position;
    return string.substring(start, end);
  }
}
