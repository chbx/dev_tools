import 'json_parser_options.dart';
import 'json_value.dart';
import 'string_scanner.dart';

class _ASCII {
  // @formatter:off
  // dart format off
  static const tab = 0x09;            // \t
  static const newline = 0x0A;        // \n
  static const carriageReturn = 0x0D; // \r
  static const space = 0x20;          // ' '
  static const doubleQuote = 0x22;    // "
  static const plus = 0x2B;           // +
  static const comma = 0x2C;          // ,
  static const minus = 0x2D;          // -
  static const dot = 0x2E;            // .
  static const slash = 0x2F;          // /
  static const char0 = 0x30;          // 0
  static const char1 = 0x31;          // 1
  static const char2 = 0x32;
  static const char3 = 0x33;
  static const char4 = 0x34;
  static const char5 = 0x35;
  static const char6 = 0x36;
  static const char7 = 0x37;
  static const char8 = 0x38;
  static const char9 = 0x39;          // 9
  static const semiColon = 0x3A;      // :
  static const char_A = 0x41;
  static const char_E = 0x45;
  static const char_F = 0x46;
  static const char_Z = 0x5A;
  static const arrayOpen = 0x5B;      // [
  static const backSlash = 0x5C;      // \
  static const arrayClose = 0x5D;     // ]
  static const char_a = 0x61;
  static const char_b = 0x62;
  static const char_z = 0x7A;
  static const char_e = 0x65;
  static const char_f = 0x66;
  static const char_l = 0x6C;
  static const char_n = 0x6e;
  static const char_r = 0x72;
  static const char_s = 0x73;
  static const char_t = 0x74;
  static const char_u = 0x75;
  static const objectOpen = 0x7B;     // {
  static const objectClose = 0x7D;    // }
  // dart format on
  // @formatter:on

  static bool isOneNine(int char) => char >= char1 && char <= char9;

  static bool isZeroNine(int char) => char >= char0 && char <= char9;

  static bool isCharE(int char) => char == char_e || char == char_E;
}

enum TokenType {
  startObject,
  endObject,
  startArray,
  endArray,
  string,
  number,
  valueTrue,
  valueFalse,
  valueNull,
  comma,
  colon,
}

class Span {
  final int start;
  final int end;

  Span({required this.start, required this.end});
}

class Token {
  final Span span;
  final TokenType type;
  final String rawText;

  final String? string;
  final JsonNumberValue? number;

  Token({
    required this.span,
    required this.type,
    required this.rawText,
    this.string,
    this.number,
  });
}

class JsonTokenizer {
  final StringScanner _scanner;
  final JsonParseOptions options;

  JsonTokenizer(String text, {required this.options})
    : _scanner = StringScanner(text);

  int _get() {
    return _scanner.get();
  }

  void _consume() {
    _scanner.consume();
  }

  Span _span(int start) {
    return Span(start: start, end: _scanner.position);
  }

  Token? nextToken() {
    // 跳过空白字符
    final char = _skipWhitespaceAndGet();
    if (char == null) {
      return null;
    }
    final start = _scanner.position;

    switch (char) {
      case _ASCII.objectOpen:
        return _parseSymbolToken(start, TokenType.startObject);
      case _ASCII.objectClose:
        return _parseSymbolToken(start, TokenType.endObject);
      case _ASCII.arrayOpen:
        return _parseSymbolToken(start, TokenType.startArray);
      case _ASCII.arrayClose:
        return _parseSymbolToken(start, TokenType.endArray);
      case _ASCII.semiColon: // ':'
        return _parseSymbolToken(start, TokenType.colon);
      case _ASCII.comma:
        return _parseSymbolToken(start, TokenType.comma);
      case _ASCII.doubleQuote:
        return _parseStringToken(start);
      case _ASCII.minus:
        return _parseNumberTokenMinus(start);
      case _ASCII.char0:
        return _parseNumberTokenZero(start);
      case _ASCII.char1:
      case _ASCII.char2:
      case _ASCII.char3:
      case _ASCII.char4:
      case _ASCII.char5:
      case _ASCII.char6:
      case _ASCII.char7:
      case _ASCII.char8:
      case _ASCII.char9:
        return _parseNumberTokenOneNine(start);
      case _ASCII.char_t:
        return _parseTrueToken(start);
      case _ASCII.char_f:
        return _parseFalseToken(start);
      case _ASCII.char_n:
        return _parseNullToken(start);
      default:
        throw FormatException(
          "Unexpected character: '${String.fromCharCode(char)}', "
          "code: $char, at position $start",
        );
    }
  }

  int? _skipWhitespaceAndGet() {
    while (!_scanner.isDone) {
      final char = _get();
      if (char == _ASCII.space ||
          char == _ASCII.tab ||
          char == _ASCII.newline ||
          char == _ASCII.carriageReturn) {
        _consume();
      } else if (char <= _ASCII.space) {
        if (options.allowControlCharsInSpace) {
          _consume();
        } else {
          throw Exception(
            'only regular white space (\r, \n, \t) is allowed between tokens',
          );
        }
      } else {
        return char;
      }
    }
    return null;
  }

  Token _parseSymbolToken(int start, TokenType type) {
    _consume(); // symbol
    return Token(
      type: type,
      span: _span(start),
      rawText: _scanner.substring(start),
    );
  }

  Token _parseStringToken(int start) {
    _consume(); // "

    StringBuffer? buffer;
    int char;
    while (!_scanner.isDone && (char = _get()) != _ASCII.doubleQuote) {
      if (char == _ASCII.backSlash) {
        buffer ??= StringBuffer(_scanner.substring(start + 1));

        _consume(); // '\'
        if (_scanner.isDone) {
          throw FormatException("Unterminated string escape at end of input");
        }

        final escapeChar = _get();
        switch (escapeChar) {
          case _ASCII.doubleQuote:
            buffer.write('"');
            _consume();
            break;
          case _ASCII.backSlash:
            buffer.write('\\');
            _consume();
            break;
          case _ASCII.slash:
            buffer.write('/');
            _consume();
            break;
          default:
            if (options.backSlashEscapeType == BackSlashEscapeType.escapeAll) {
              switch (escapeChar) {
                case _ASCII.char_b:
                  buffer.write('\b');
                  _consume();
                  break;
                case _ASCII.char_f:
                  buffer.write('\f');
                  _consume();
                  break;
                case _ASCII.char_n:
                  buffer.write('\n');
                  _consume();
                  break;
                case _ASCII.char_r:
                  buffer.write('\r');
                  _consume();
                  break;
                case _ASCII.char_t:
                  buffer.write('\t');
                  _consume();
                  break;
                case _ASCII.char_u: // \uXXXX - Unicode
                  _consume(); // 跳过 'u'

                  if (!_scanner.hasMore(4)) {
                    throw FormatException("Incomplete unicode escape sequence");
                  }

                  final position = _scanner.position;
                  final hex = _scanner.substring(position, position + 4);
                  int? codeUnit;

                  try {
                    codeUnit = int.tryParse(hex, radix: 16);
                  } catch (e) {
                    throw FormatException(
                      "Invalid unicode escape sequence: \\u$hex",
                    );
                  }

                  if (codeUnit == null ||
                      codeUnit > 0xD7FF && codeUnit < 0xE000 ||
                      codeUnit > 0xFFFF) {
                    throw FormatException(
                      "Invalid unicode scalar value: $codeUnit",
                    );
                  }

                  buffer.writeCharCode(codeUnit);
                  _scanner.forward(4);
                  break;
                default:
                  if (options.allowBackSlashEscapingAnyCharacter) {
                    buffer.writeCharCode(_ASCII.backSlash);
                    buffer.writeCharCode(escapeChar);
                    _consume();
                  } else {
                    throw Exception(
                      'Unrecognized character escape ${String.fromCharCode(char)}',
                    );
                  }
              }
            } else {
              buffer.writeCharCode(_ASCII.backSlash);
              buffer.writeCharCode(escapeChar);
              _consume();
            }
            break;
        }
      } else {
        if (!options.allowBackSlashEscapingAnyCharacter &&
            char < _ASCII.space) {
          throw Exception(
            'Illegal unquoted character (code: $char): has to be escaped'
            ' using backslash to be included in string value',
          );
        }
        // 正常字符直接加入 buffer
        buffer?.writeCharCode(char);
        _consume();
      }
    }

    if (_scanner.isDone) {
      throw FormatException("Unterminated string at position $start");
    } else {
      _consume(); // 跳过结尾的引号 "
    }

    return Token(
      span: _span(start),
      type: TokenType.string,
      rawText: _scanner.substring(start),
      string: buffer?.toString(),
    );
  }

  Token _parseNumberTokenMinus(int start) {
    _consume(); // '-'
    if (_scanner.isDone) {
      throw FormatException("Invalid number format at position $start");
    }
    final char = _get();
    if (char == _ASCII.char0) {
      return _parseNumberTokenZero(start);
    } else if (_ASCII.isOneNine(char)) {
      return _parseNumberTokenOneNine(start);
    } else {
      throw FormatException("Invalid number format at position $start");
    }
  }

  Token _parseNumberTokenZero(int start) {
    _consume(); // '0'
    if (!_scanner.isDone) {
      final char = _get();
      if (_ASCII.isOneNine(char)) {
        throw FormatException(
          "Invalid leading zero in number at position $start",
        );
      } else if (char == _ASCII.dot) {
        return _parseNumberTokenPartDot(start);
      } else if (_ASCII.isCharE(char)) {
        return _parseNumberTokenPartE(start);
      }
    }
    final rawText = _scanner.substring(start);
    return Token(
      span: _span(start),
      type: TokenType.number,
      rawText: rawText,
      // TODO Zero
      number: JsonNumberValueInt(int.parse(rawText)),
    );
  }

  Token _parseNumberTokenOneNine(int start) {
    _consume();
    while (!_scanner.isDone) {
      final char = _get();
      if (_ASCII.isZeroNine(char)) {
        _consume();
      } else if (char == _ASCII.dot) {
        return _parseNumberTokenPartDot(start);
      } else if (_ASCII.isCharE(char)) {
        return _parseNumberTokenPartE(start);
      } else {
        break;
      }
    }
    final rawText = _scanner.substring(start);
    return Token(
      span: _span(start),
      type: TokenType.number,
      rawText: rawText,
      // TODO big int
      number: JsonNumberValueInt(int.parse(rawText)),
    );
  }

  Token _parseNumberTokenPartDot(int start) {
    _consume(); // .

    // 小数点后必须有数字
    if (_scanner.isDone) {
      throw FormatException(
        "Missing digits after decimal point at position $start",
      );
    }
    final char = _get();
    if (!_ASCII.isZeroNine(char)) {
      // 小数点后必须有数字
      throw FormatException(
        "Missing digits after decimal point at position $start",
      );
    }
    _consume();
    while (!_scanner.isDone) {
      final char = _get();
      if (_ASCII.isZeroNine(char)) {
        _consume();
      } else if (_ASCII.isCharE(char)) {
        _parseNumberTokenPartE(start);
      } else {
        break;
      }
    }

    final rawText = _scanner.substring(start);
    return Token(
      span: _span(start),
      type: TokenType.number,
      rawText: rawText,
      number: JsonNumberValueFloat(double.parse(rawText)),
    );
  }

  Token _parseNumberTokenPartE(int start) {
    _consume(); // e or E

    // 指数部分可以有可选的符号 + -
    if (!_scanner.isDone) {
      final char = _get();
      if (char == _ASCII.minus || char == _ASCII.plus) {
        _consume();
      }
    }
    // 指数部分必须有数字
    if (_scanner.isDone) {
      throw FormatException("Missing exponent digits at position $start");
    }
    final char = _get();
    // 指数部分必须有数字
    if (!_ASCII.isZeroNine(char)) {
      throw FormatException(
        "Missing digits after decimal point at position $start",
      );
    }
    _consume();
    while (!_scanner.isDone) {
      if (_ASCII.isZeroNine(_get())) {
        _consume();
      } else {
        break;
      }
    }
    final rawText = _scanner.substring(start);
    return Token(
      span: _span(start),
      type: TokenType.number,
      rawText: rawText,
      number: JsonNumberValueFloat(double.parse(rawText)),
    );
  }

  Token _parseTrueToken(int start) {
    final token = _literal(
      start: start,
      extraCount: 3,
      literal: "true",
      tokenType: TokenType.valueTrue,
    );
    if (token == null) {
      throw FormatException("Invalid boolean literal 'true'");
    }
    return token;
  }

  Token _parseFalseToken(int start) {
    final token = _literal(
      start: start,
      extraCount: 4,
      literal: "false",
      tokenType: TokenType.valueFalse,
    );
    if (token == null) {
      throw FormatException("Invalid boolean literal 'false'");
    }
    return token;
  }

  Token _parseNullToken(int start) {
    final token = _literal(
      start: start,
      extraCount: 3,
      literal: "null",
      tokenType: TokenType.valueNull,
    );
    if (token == null) {
      throw FormatException("Invalid null literal");
    }
    return token;
  }

  Token? _literal({
    required int start,
    required int extraCount,
    required String literal,
    required TokenType tokenType,
  }) {
    final position = _scanner.position;
    if (_scanner.hasMore(extraCount) &&
        _scanner.substring(position, position + extraCount + 1) == literal) {
      _scanner.forward(extraCount + 1);
      return Token(span: _span(start), type: tokenType, rawText: literal);
    }
    return null;
  }
}
