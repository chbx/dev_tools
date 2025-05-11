const _charCodeDoubleQuote = 0x22; // "
const _charCodeBackslash = 0x5C; // \

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

class JsonNumberValue {}

class JsonNumberValueInt extends JsonNumberValue {
  final int intValue;

  JsonNumberValueInt(this.intValue);
}

class JsonNumberValueFloat extends JsonNumberValue {
  final double floatValue;

  JsonNumberValueFloat(this.floatValue);
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

class Tokenizer {
  final String text;

  int position = 0;

  Tokenizer(this.text);

  Token? nextToken() {
    if (position >= text.length) {
      return null; // 结束输入
    }

    // int start = position;
    int char = _get();

    // 跳过空白字符
    while (char <= 0x20) {
      _consume();
      if (position >= text.length) {
        return null;
      }
      char = _get();
    }
    int start = position;

    switch (char) {
      case 0x7B: // '{'
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.startObject,
          rawText: text.substring(start, position),
        );
      case 0x7D: // '}'
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.endObject,
          rawText: text.substring(start, position),
        );
      case 0x5B: // '['
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.startArray,
          rawText: text.substring(start, position),
        );
      case 0x5D: // ']'
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.endArray,
          rawText: text.substring(start, position),
        );
      case 0x3A: // ':'
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.colon,
          rawText: text.substring(start, position),
        );
      case 0x2C: // ','
        _consume();
        return Token(
          span: Span(start: start, end: position),
          type: TokenType.comma,
          rawText: text.substring(start, position),
        );
      case 0x22: // '"'
        return _parseStringToken(start);
      case 0x2D: // '-'
      case 0x30: // '0'
      case 0x31:
      case 0x32:
      case 0x33:
      case 0x34:
      case 0x35:
      case 0x36:
      case 0x37:
      case 0x38:
      case 0x39: // '9'
        return _parseNumberToken(start);
      case 0x74: // 't' - 可能是 true
        return _parseTrueToken(start);
      case 0x66: // 'f' - 可能是 false
        return _parseFalseToken(start);
      case 0x6E: // 'n' - 可能是 null
        return _parseNullToken(start);
      default:
        throw FormatException(
          "Unexpected character: '$char', at position $position",
        );
    }
  }

  int _get() {
    return text.codeUnitAt(position);
  }

  void _consume() {
    position += 1;
  }

  Token _parseStringToken(int start) {
    _consume(); // 跳过开头的引号 "

    final buffer = StringBuffer();
    int char;

    while (position < text.length && (char = _get()) != _charCodeDoubleQuote) {
      if (char == _charCodeBackslash) {
        _consume(); // 消耗 '\'
        if (position >= text.length) {
          throw FormatException("Unterminated string escape at end of input");
        }

        final escapeChar = _get();
        switch (escapeChar) {
          case 0x22: // \"
            buffer.write('"');
            _consume();
            break;
          case 0x5C: // \\
            buffer.write('\\');
            _consume();
            break;
          case 0x2F: // \/
            buffer.write('/');
            _consume();
            break;
          // case 0x62: // \b
          //   buffer.write('\b');
          //   _consume();
          //   break;
          // case 0x66: // \f
          //   buffer.write('\f');
          //   _consume();
          //   break;
          // case 0x6E: // \n
          //   buffer.write('\n');
          //   _consume();
          //   break;
          // case 0x72: // \r
          //   buffer.write('\r');
          //   _consume();
          //   break;
          // case 0x74: // \t
          //   buffer.write('\t');
          //   _consume();
          //   break;
          // case 0x75: // \uXXXX - Unicode
          //   _consume(); // 跳过 'u'
          //
          //   if (position + 4 > text.length) {
          //     throw FormatException("Incomplete unicode escape sequence");
          //   }
          //
          //   String hex = text.substring(position, position + 4);
          //   int? codeUnit;
          //
          //   try {
          //     codeUnit = int.tryParse(hex, radix: 16);
          //   } catch (e) {
          //     throw FormatException("Invalid unicode escape sequence: \\u$hex");
          //   }
          //
          //   if (codeUnit == null || codeUnit > 0xD7FF && codeUnit < 0xE000 || codeUnit > 0xFFFF) {
          //     throw FormatException("Invalid unicode scalar value: $codeUnit");
          //   }
          //
          //   buffer.write(String.fromCharCode(codeUnit));
          //   position += 4;
          //   break;
          default:
            //  throw FormatException("Invalid escape character: \\x${escapeChar.toRadixString(16)}");
            buffer.write('\\');
            buffer.write(String.fromCharCode(char));
        }
      } else {
        // 正常字符直接加入 buffer
        buffer.write(String.fromCharCode(char));
        _consume();
      }
    }

    if (position < text.length) {
      _consume(); // 跳过结尾的引号 "
    }

    return Token(
      span: Span(start: start, end: position),
      type: TokenType.string,
      rawText: text.substring(start, position),
      string: buffer.toString(),
    );
  }

  Token _parseNumberToken(int start) {
    bool hasDot = false;

    while (position < text.length) {
      int char = text.codeUnitAt(position);
      if ((char == 0x2D && position == start) ||
          (char >= 0x30 && char <= 0x39) ||
          char == 0x2E ||
          char == 0x45 ||
          char == 0x65) {
        if (char == 0x2E) hasDot = true;
        _consume();
      } else {
        break;
      }
    }

    String numStr = text.substring(start, position);
    JsonNumberValue number;
    if (hasDot) {
      number = JsonNumberValueFloat(double.parse(numStr));
    } else {
      number = JsonNumberValueInt(int.parse(numStr));
    }

    return Token(
      span: Span(start: start, end: position),
      type: TokenType.number,
      rawText: numStr,
      number: number,
    );
  }

  Token _parseTrueToken(int start) {
    if (position + 3 <= text.length &&
        text.substring(position, position + 4) == "true") {
      position += 4;
      return Token(
        span: Span(start: start, end: position),
        type: TokenType.valueTrue,
        rawText: "true",
      );
    }
    throw FormatException("Invalid boolean literal 'true'");
  }

  Token _parseFalseToken(int start) {
    if (position + 4 <= text.length &&
        text.substring(position, position + 5) == "false") {
      position += 5;
      return Token(
        span: Span(start: start, end: position),
        type: TokenType.valueFalse,
        rawText: "false",
      );
    }
    throw FormatException("Invalid boolean literal 'false'");
  }

  Token _parseNullToken(int start) {
    if (position + 3 <= text.length &&
        text.substring(position, position + 4) == "null") {
      position += 4;
      return Token(
        span: Span(start: start, end: position),
        type: TokenType.valueNull,
        rawText: "null",
      );
    }
    throw FormatException("Invalid null literal");
  }
}
