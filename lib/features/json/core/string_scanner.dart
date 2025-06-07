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

  int readChar() {
    if (isDone) _fail('more input');
    return string.codeUnitAt(_position++);
  }

  int? peekChar([int? offset]) {
    offset ??= 0;
    final index = position + offset;
    if (index < 0 || index >= string.length) return null;
    return string.codeUnitAt(index);
  }

  void expectCharCode(int charcode) {
    final c = readChar();
    if (c != charcode) {
      String name;
      if (charcode == 0x5C) {
        // '\\'
        name = r'"\"';
      } else if (charcode == 0x22) {
        // '"'
        name = r'"\""';
      } else {
        name = '"${String.fromCharCode(charcode)}"';
      }

      _fail('expected $name, got $c');
    }
  }

  Never _fail(String name) {
    throw FormatException('Expected $name', string, position);
  }
}
