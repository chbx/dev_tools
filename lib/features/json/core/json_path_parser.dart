import '_ascii.dart';
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

  // $
  void _processRootNode() {
    _readWhitespace();
    if (_scanner.peekChar() == ASCII.dollar) {
      _scanner.consume();
    } else {
      _fail(r"Expected Root Node '$'");
    }
  }

  JsonPath _innerParse() {
    while (!_scanner.isDone) {
      _readWhitespace();
      if (_scanner.isDone) {
        break;
      }
      final c = _scanner.readChar();
      switch (c) {
        case ASCII.lbracket:
          _processBracketSegment();
          break;
        case ASCII.dot:
          _processDotSegment();
          break;
        default:
          break;
      }
    }
    return JsonPath(path: _scanner.string, segments: _segments);
  }

  // . AND ..
  void _processDotSegment() {
    final c = _scanner.readChar();
    if (c == ASCII.dot) {
      throw UnimplementedError('segment \'..\' not implemented');
    } else {
      final propertyName = _readProperty(c);
      _segments.add(JsonPathSegmentSingleName(propertyName));
    }
  }

  // '['
  void _processBracketSegment() {
    _readWhitespace();
    final start = _scanner.position;
    final c = _scanner.readChar();
    if (c == ASCII.doubleQuote) {
      throw UnimplementedError(
        'segment \'[\' with double quote not implemented',
      );
    } else if (c == ASCII.singleQuote) {
      throw UnimplementedError(
        'segment \'[\' with single quote not implemented',
      );
    } else if (c == ASCII.wildcard) {
      _segments.add(JsonPathSegmentWildcard());
    } else if (c == ASCII.char0) {
      _readWhitespace();
      final peekNext = _scanner.peekChar();
      if (peekNext != null && ASCII.isZeroNine(peekNext)) {
        _fail('number format error: leading 0 is not allowed');
      } else {
        _segments.add(JsonPathSegmentSingleIndex(0));
      }
    } else if (c == ASCII.minus) {
      final nextC = _scanner.readChar();
      if (ASCII.isOneNine(nextC)) {
        while (!_scanner.isDone) {
          final numC = _scanner.peekChar();
          if (numC == null || !ASCII.isZeroNine(numC)) {
            break;
          } else {
            _scanner.consume();
          }
        }
        final index = int.parse(_scanner.substring(start));
        _segments.add(JsonPathSegmentSingleIndex(index));
      } else {
        _fail('number format error: minus mark should be followed by digit');
      }
    } else if (ASCII.isOneNine(c)) {
      while (!_scanner.isDone) {
        final numC = _scanner.peekChar();
        if (numC == null || !ASCII.isZeroNine(numC)) {
          break;
        } else {
          _scanner.consume();
        }
      }
      final index = int.parse(_scanner.substring(start));
      _segments.add(JsonPathSegmentSingleIndex(index));
    } else {
      _fail('segment \'[ content error');
    }

    // expected ']'
    _readWhitespace();
    _scanner.expectCharCode(ASCII.rbracket);
  }

  String _readProperty(int? first) {
    final buffer = StringBuffer();

    // first char
    final int c;
    if (first != null) {
      c = first;
    } else {
      c = _scanner.readChar();
    }

    if (ASCII.isAlpha(c) || c == ASCII.underline || c >= ASCII.beyondAscii) {
      buffer.writeCharCode(c);
    } else {
      var escapeChar = false;
      if (escapeDotName) {
        if (c == ASCII.backSlash) {
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
      final c = _scanner.get();
      if (ASCII.isAlpha(c) ||
          c == ASCII.underline ||
          c >= ASCII.beyondAscii ||
          ASCII.isZeroNine(c)) {
        buffer.writeCharCode(c);
        _scanner.consume();
      } else {
        if (!escapeDotName) {
          break;
        }

        if (c == ASCII.backSlash) {
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
      case ASCII.minus:
        return ASCII.minus;
      case ASCII.underline:
        return ASCII.underline;
      case ASCII.backSlash:
        return ASCII.backSlash;
      case ASCII.slash:
        return ASCII.slash;
      default:
        return null;
    }
  }

  void _readWhitespace() {
    while (!_scanner.isDone) {
      final c = _scanner.peekChar();
      if (c == ASCII.space ||
          c == ASCII.space ||
          c == ASCII.newline ||
          c == ASCII.carriageReturn) {
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
