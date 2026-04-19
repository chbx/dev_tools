enum JsonTokenType {
  key,
  colon,
  string,
  number,
  literal,
  bracket,
  comma,
  hint,
}

enum JsonLineType {
  objectStart,
  objectEnd,
  arrayStart,
  arrayEnd,
  emptyObject,
  emptyArray,
  value,
}

/// Typed text fragment that the View layer uses directly to build colored TextSpans.
class JsonLineToken {
  final String text;
  final JsonTokenType type;
  final int bracketDepth;

  const JsonLineToken(this.text, this.type, {this.bracketDepth = 0});
}

/// A logical line in the Model coordinate system.
class JsonLine {
  final int lineNumber;
  final String content;
  final int indentLevel;
  final JsonLineType lineType;
  final List<JsonLineToken> tokens;

  const JsonLine({
    required this.lineNumber,
    required this.content,
    required this.indentLevel,
    required this.lineType,
    required this.tokens,
  });
}
