import '_ascii.dart';
import 'json_parser_options.dart';
import 'json_value.dart';
import 'string_scanner.dart';

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
      case ASCII.objectOpen:
        return _parseSymbolToken(start, TokenType.startObject);
      case ASCII.objectClose:
        return _parseSymbolToken(start, TokenType.endObject);
      case ASCII.lbracket:
        return _parseSymbolToken(start, TokenType.startArray);
      case ASCII.rbracket:
        return _parseSymbolToken(start, TokenType.endArray);
      case ASCII.semiColon: // ':'
        return _parseSymbolToken(start, TokenType.colon);
      case ASCII.comma:
        return _parseSymbolToken(start, TokenType.comma);
      case ASCII.doubleQuote:
        return _parseStringToken(start);
      case ASCII.minus:
        return _parseNumberTokenMinus(start);
      case ASCII.char0:
        return _parseNumberTokenZero(start);
      case ASCII.char1:
      case ASCII.char2:
      case ASCII.char3:
      case ASCII.char4:
      case ASCII.char5:
      case ASCII.char6:
      case ASCII.char7:
      case ASCII.char8:
      case ASCII.char9:
        return _parseNumberTokenOneNine(start);
      case ASCII.char_t:
        return _parseTrueToken(start);
      case ASCII.char_f:
        return _parseFalseToken(start);
      case ASCII.char_n:
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
      if (char == ASCII.space ||
          char == ASCII.tab ||
          char == ASCII.newline ||
          char == ASCII.carriageReturn) {
        _consume();
      } else if (char <= ASCII.space) {
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
    while (!_scanner.isDone && (char = _get()) != ASCII.doubleQuote) {
      if (char == ASCII.backSlash) {
        buffer ??= StringBuffer(_scanner.substring(start + 1));

        _consume(); // '\'
        if (_scanner.isDone) {
          throw FormatException("Unterminated string escape at end of input");
        }

        final escapeChar = _get();
        switch (escapeChar) {
          case ASCII.doubleQuote:
            buffer.write('"');
            _consume();
            break;
          case ASCII.backSlash:
            buffer.write('\\');
            _consume();
            break;
          case ASCII.slash:
            buffer.write('/');
            _consume();
            break;
          default:
            if (options.backSlashEscapeType == BackSlashEscapeType.escapeAll) {
              switch (escapeChar) {
                case ASCII.char_b:
                  buffer.write('\b');
                  _consume();
                  break;
                case ASCII.char_f:
                  buffer.write('\f');
                  _consume();
                  break;
                case ASCII.char_n:
                  buffer.write('\n');
                  _consume();
                  break;
                case ASCII.char_r:
                  buffer.write('\r');
                  _consume();
                  break;
                case ASCII.char_t:
                  buffer.write('\t');
                  _consume();
                  break;
                case ASCII.char_u: // \uXXXX - Unicode
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
                    buffer.writeCharCode(ASCII.backSlash);
                    buffer.writeCharCode(escapeChar);
                    _consume();
                  } else {
                    throw Exception(
                      'Unrecognized character escape ${String.fromCharCode(char)}',
                    );
                  }
              }
            } else {
              buffer.writeCharCode(ASCII.backSlash);
              buffer.writeCharCode(escapeChar);
              _consume();
            }
            break;
        }
      } else {
        if (!options.allowBackSlashEscapingAnyCharacter && char < ASCII.space) {
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
    if (char == ASCII.char0) {
      return _parseNumberTokenZero(start);
    } else if (ASCII.isOneNine(char)) {
      return _parseNumberTokenOneNine(start);
    } else {
      throw FormatException("Invalid number format at position $start");
    }
  }

  Token _parseNumberTokenZero(int start) {
    _consume(); // '0'
    if (!_scanner.isDone) {
      final char = _get();
      if (ASCII.isOneNine(char)) {
        throw FormatException(
          "Invalid leading zero in number at position $start",
        );
      } else if (char == ASCII.dot) {
        return _parseNumberTokenPartDot(start);
      } else if (ASCII.isCharE(char)) {
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
      if (ASCII.isZeroNine(char)) {
        _consume();
      } else if (char == ASCII.dot) {
        return _parseNumberTokenPartDot(start);
      } else if (ASCII.isCharE(char)) {
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
    if (!ASCII.isZeroNine(char)) {
      // 小数点后必须有数字
      throw FormatException(
        "Missing digits after decimal point at position $start",
      );
    }
    _consume();
    while (!_scanner.isDone) {
      final char = _get();
      if (ASCII.isZeroNine(char)) {
        _consume();
      } else if (ASCII.isCharE(char)) {
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
      if (char == ASCII.minus || char == ASCII.plus) {
        _consume();
      }
    }
    // 指数部分必须有数字
    if (_scanner.isDone) {
      throw FormatException("Missing exponent digits at position $start");
    }
    final char = _get();
    // 指数部分必须有数字
    if (!ASCII.isZeroNine(char)) {
      throw FormatException(
        "Missing digits after decimal point at position $start",
      );
    }
    _consume();
    while (!_scanner.isDone) {
      if (ASCII.isZeroNine(_get())) {
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
