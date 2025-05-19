import 'charcodes.dart';
import 'json_path.dart';
import 'json_path_segment.dart';
import 'string_scanner.dart';

class JsonPathParser {
  final StringScanner _scanner;

  final List<JsonPathSegment> _segments = [];
  final bool escapeDotName;

  JsonPathParser(this._scanner, {this.escapeDotName = false});

  static JsonPath? parse(String path, {bool fastJsonMode = false}) {
    final parser = JsonPathParser(
      StringScanner(path),
      escapeDotName: fastJsonMode,
    );
    parser._processRootNode();
    return parser._innerParse();
  }

  JsonPath _innerParse() {
    while (!_scanner.isDone) {
      _readWhitespace();
      if (_scanner.isDone) {
        break;
      }
      final c = _scanner.readChar();
      switch (c) {
        case $LBRACKET:
          _processBracketSegment();
          break;
        case $DOT:
          _processDotSegment();
          break;
        default:
          break;
      }
    }
    return JsonPath(path: _scanner.string, segments: _segments);
  }

  // $
  void _processRootNode() {
    _readWhitespace();
    if (_scanner.peekChar() == $DOLLAR) {
      _scanner.consume();
    } else {
      _fail(r"Expected Root Node '$'");
    }
  }

  // . AND ..
  void _processDotSegment() {
    final c = _scanner.readChar();
    if (c == $DOT) {
      throw UnimplementedError('segment \'..\' not implemented');
    } else {
      final propertyName = _readProperty(c);
      _segments.add(JsonPathSegmentSingleName(propertyName));
    }
  }

  // '['
  void _processBracketSegment() {
    _readWhitespace();
    int start = _scanner.position;
    final c = _scanner.readChar();
    if (c == $DOUBLE_QUOTE) {
      throw UnimplementedError(
        'segment \'[\' with double quote not implemented',
      );
    } else if (c == $SINGLE_QUOTE) {
      throw UnimplementedError(
        'segment \'[\' with single quote not implemented',
      );
    } else if (c == $WILDCARD) {
      _segments.add(JsonPathSegmentWildcard());
    } else if (c == $CHAR_0) {
      _readWhitespace();
      final peekNext = _scanner.peekChar();
      if (peekNext != null && _isDigit09(peekNext)) {
        _fail('number format error: leading 0 is not allowed');
      } else {
        _segments.add(JsonPathSegmentSingleIndex(0));
      }
    } else if (c == $MINUS) {
      var nextC = _scanner.readChar();
      if (_isDigit19(nextC)) {
        while (!_scanner.isDone) {
          var numC = _scanner.peekChar();
          if (numC == null || !_isDigit09(numC)) {
            break;
          }
        }
        final index = int.parse(_scanner.substring(start));
        _segments.add(JsonPathSegmentSingleIndex(index));
      } else {
        _fail('number format error: minus mark should be followed by digit');
      }
    } else if (_isDigit19(c)) {
      while (!_scanner.isDone) {
        var numC = _scanner.peekChar();
        if (numC == null || !_isDigit09(numC)) {
          break;
        }
      }
      final index = int.parse(_scanner.substring(start));
      _segments.add(JsonPathSegmentSingleIndex(index));
    } else {
      _fail('segment \'[ content error');
    }

    // expected ']'
    _readWhitespace();
    _scanner.expectCharCode($RBRACKET);
  }

  String _readProperty(int? first) {
    StringBuffer buffer = StringBuffer();

    // first char
    final int c;
    if (first != null) {
      c = first;
    } else {
      c = _scanner.readChar();
    }

    if (_isAlpha(c) || c == $UNDERLINE || c >= $BEYOUND_ASCII) {
      buffer.writeCharCode(c);
    } else {
      var escapeChar = false;
      if (escapeDotName) {
        if (c == $BACKSLASH) {
          final nextC = _scanner.readChar();
          final escape = _readEscape(nextC);
          if (escape != null) {
            buffer.writeCharCode(escape);
            escapeChar = true;
          }
        }
      }
      if (!escapeChar) {
        _fail(r"Expected property name");
      }
    }

    // extra chars
    while (!_scanner.isDone) {
      final c = _scanner.currentChar;
      if (_isAlpha(c) ||
          c == $UNDERLINE ||
          c >= $BEYOUND_ASCII ||
          _isDigit09(c)) {
        buffer.writeCharCode(c);
        _scanner.consume();
      } else {
        if (!escapeDotName) {
          break;
        }

        if (c == $BACKSLASH) {
          bool readChar = false;
          final nextC = _scanner.peekChar(1);
          if (nextC != null) {
            final escape = _readEscape(nextC);
            if (escape != null) {
              buffer.writeCharCode(escape);
              _scanner.consume();
              _scanner.consume();
              readChar = true;
            }
          }
          if (!readChar) {
            break;
          }
        } else {
          break;
        }
      }
    }
    return buffer.toString();
  }

  int? _readEscape(int c) {
    switch (c) {
      case $MINUS:
        return $MINUS;
      default:
        return null;
    }
  }

  bool _isAlpha(int c) {
    return (c >= $CHAR_a && c <= $CHAR_z) || (c >= $CHAR_A && c <= $CHAR_Z);
  }

  bool _isDigit09(int c) {
    return c >= $CHAR_0 && c <= $CHAR_9;
  }

  bool _isDigit19(int c) {
    return c >= $CHAR_1 && c <= $CHAR_9;
  }

  void _readWhitespace() {
    while (!_scanner.isDone) {
      var c = _scanner.peekChar();
      if (c == $SPACE || c == $TAB || c == $NEWLINE || c == $CARRIAGE_RETURN) {
        _scanner.consume();
      } else {
        break;
      }
    }
  }

  Never _fail(String message) {
    throw Exception(message);
  }
}
