import 'dart:collection';

import '../model/json_line.dart';
import '../model/json_value.dart';
import 'to_string.dart';

List<JsonLine> buildJsonLines(
  JsonValue rootValue, {
  int baseIndent = 0,
  int baseBracketDepth = 0,
}) {
  final builder = _JsonLineBuilder();
  builder._buildLines(
    rootValue,
    indent: baseIndent,
    comma: false,
    bracketDepth: baseBracketDepth,
  );
  return builder._lines;
}

class _JsonLineBuilder {
  final List<JsonLine> _lines = [];
  int _lineCount = 0;

  void _buildLines(
    JsonValue value, {
    required int indent,
    required bool comma,
    String? keyString,
    required int bracketDepth,
  }) {
    switch (value) {
      case JsonNull():
        _addLeafLine(
          indent: indent,
          comma: comma,
          keyString: keyString,
          valueText: value.rawText,
          tokenType: JsonTokenType.literal,
          bracketDepth: bracketDepth,
        );
      case JsonBool():
        _addLeafLine(
          indent: indent,
          comma: comma,
          keyString: keyString,
          valueText: value.rawText,
          tokenType: JsonTokenType.literal,
          bracketDepth: bracketDepth,
        );
      case JsonNumber():
        _addLeafLine(
          indent: indent,
          comma: comma,
          keyString: keyString,
          valueText: value.rawText,
          tokenType: JsonTokenType.number,
          hintString: value.dateHint,
          bracketDepth: bracketDepth,
        );
      case JsonString():
        _buildStringLines(
          value,
          indent: indent,
          comma: comma,
          keyString: keyString,
          bracketDepth: bracketDepth,
        );
      case JsonArray():
        _buildArrayLines(
          value,
          indent: indent,
          comma: comma,
          keyString: keyString,
          bracketDepth: bracketDepth,
        );
      case NormalJsonObject():
        _buildObjectLines(
          value.entryMap,
          indent: indent,
          comma: comma,
          keyString: keyString,
          bracketDepth: bracketDepth,
          keyExtractor: (JsonObjectKeyString key) => key.value.rawText,
          refValue: value.ref,
          shortString: value.shortString,
        );
      case ExtendedJsonObject():
        _buildObjectLines(
          value.entryMap,
          indent: indent,
          comma: comma,
          keyString: keyString,
          bracketDepth: bracketDepth,
          keyExtractor: _objectKeyToString,
        );
    }
  }

  void _buildStringLines(
    JsonString value, {
    required int indent,
    required bool comma,
    String? keyString,
    required int bracketDepth,
  }) {
    final parsed = value.parsed;
    if (parsed != null) {
      switch (parsed) {
        case JsonArray():
          _buildArrayLines(
            parsed,
            indent: indent,
            comma: comma,
            keyString: keyString,
            bracketDepth: bracketDepth,
            parsedFromRawText: value.rawText,
          );
          return;
        case NormalJsonObject():
          _buildObjectLines(
            parsed.entryMap,
            indent: indent,
            comma: comma,
            keyString: keyString,
            bracketDepth: bracketDepth,
            keyExtractor: (JsonObjectKeyString key) => key.value.rawText,
            parsedFromRawText: value.rawText,
          );
          return;
        case ExtendedJsonObject():
          _buildObjectLines(
            parsed.entryMap,
            indent: indent,
            comma: comma,
            keyString: keyString,
            bracketDepth: bracketDepth,
            keyExtractor: _objectKeyToString,
            parsedFromRawText: value.rawText,
          );
          return;
        default:
          break;
      }
    }

    _addLeafLine(
      indent: indent,
      comma: comma,
      keyString: keyString,
      valueText: value.rawText,
      tokenType: JsonTokenType.string,
      bracketDepth: bracketDepth,
    );
  }

  void _buildArrayLines(
    JsonArray value, {
    required int indent,
    required bool comma,
    String? keyString,
    required int bracketDepth,
    String? parsedFromRawText,
  }) {
    final depth = bracketDepth;
    if (value.elements.isEmpty) {
      _addLine(
        indent: indent,
        lineType: JsonLineType.emptyArray,
        tokens: [
          ..._keyTokens(keyString),
          JsonLineToken('[ ]', JsonTokenType.bracket, bracketDepth: depth),
          if (comma) const JsonLineToken(',', JsonTokenType.comma),
        ],
      );
      return;
    }

    _addLine(
      indent: indent,
      lineType: JsonLineType.arrayStart,
      childCount: value.elements.length,
      parsedFromRawText: parsedFromRawText,
      tokens: [
        ..._keyTokens(keyString),
        JsonLineToken('[', JsonTokenType.bracket, bracketDepth: depth),
      ],
    );

    for (int i = 0; i < value.elements.length; i++) {
      _buildLines(
        value.elements[i],
        indent: indent + 1,
        comma: i < value.elements.length - 1,
        bracketDepth: depth + 1,
      );
    }

    _addLine(
      indent: indent,
      lineType: JsonLineType.arrayEnd,
      tokens: [
        JsonLineToken(']', JsonTokenType.bracket, bracketDepth: depth),
        if (comma) const JsonLineToken(',', JsonTokenType.comma),
      ],
    );
  }

  void _buildObjectLines<T>(
    LinkedHashMap<T, JsonValue> entryMap, {
    required int indent,
    required bool comma,
    String? keyString,
    required int bracketDepth,
    required String Function(T key) keyExtractor,
    String? parsedFromRawText,
    JsonValue? refValue,
    String? shortString,
  }) {
    final depth = bracketDepth;
    if (entryMap.isEmpty) {
      _addLine(
        indent: indent,
        lineType: JsonLineType.emptyObject,
        tokens: [
          ..._keyTokens(keyString),
          JsonLineToken('{ }', JsonTokenType.bracket, bracketDepth: depth),
          if (comma) const JsonLineToken(',', JsonTokenType.comma),
        ],
      );
      return;
    }

    _addLine(
      indent: indent,
      lineType: JsonLineType.objectStart,
      childCount: entryMap.length,
      parsedFromRawText: parsedFromRawText,
      refValue: refValue,
      shortString: shortString,
      tokens: [
        ..._keyTokens(keyString),
        JsonLineToken('{', JsonTokenType.bracket, bracketDepth: depth),
      ],
    );

    final entries = entryMap.entries.toList();
    for (int idx = 0; idx < entries.length; idx++) {
      final entryKey = keyExtractor(entries[idx].key);
      _buildLines(
        entries[idx].value,
        indent: indent + 1,
        comma: idx < entries.length - 1,
        keyString: entryKey,
        bracketDepth: depth + 1,
      );
    }

    _addLine(
      indent: indent,
      lineType: JsonLineType.objectEnd,
      tokens: [
        JsonLineToken('}', JsonTokenType.bracket, bracketDepth: depth),
        if (comma) const JsonLineToken(',', JsonTokenType.comma),
      ],
    );
  }

  // ---- helpers ----

  void _addLeafLine({
    required int indent,
    required bool comma,
    String? keyString,
    required String valueText,
    required JsonTokenType tokenType,
    String? hintString,
    required int bracketDepth,
  }) {
    final tokens = <JsonLineToken>[
      ..._keyTokens(keyString),
      JsonLineToken(valueText, tokenType, bracketDepth: bracketDepth),
      if (comma) const JsonLineToken(',', JsonTokenType.comma),
      if (hintString != null) JsonLineToken(' // $hintString', JsonTokenType.hint),
    ];
    _addLine(indent: indent, lineType: JsonLineType.value, tokens: tokens);
  }

  List<JsonLineToken> _keyTokens(String? keyString) {
    if (keyString == null) return const [];
    return [
      JsonLineToken(keyString, JsonTokenType.key),
      const JsonLineToken(': ', JsonTokenType.colon),
    ];
  }

  void _addLine({
    required int indent,
    required JsonLineType lineType,
    required List<JsonLineToken> tokens,
    int? childCount,
    String? parsedFromRawText,
    JsonValue? refValue,
    String? shortString,
  }) {
    final content = tokens.map((t) => t.text).join();
    _lines.add(JsonLine(
      lineNumber: _lineCount++,
      content: content,
      indentLevel: indent,
      lineType: lineType,
      tokens: tokens,
      isBasicASCII: _checkBasicASCII(content),
      childCount: childCount,
      parsedFromRawText: parsedFromRawText,
      refValue: refValue,
      shortString: shortString,
    ));
  }

  /// Checks whether a string consists entirely of basic ASCII (printable characters, code points 32~126).
  bool _checkBasicASCII(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code < 32 || code > 126) return false;
    }
    return true;
  }

  String _objectKeyToString(JsonObjectKey key) {
    return switch (key) {
      JsonObjectKeyString() => key.value.rawText,
      JsonObjectKeyNumber() => key.value.rawText,
      JsonObjectKeyBool() => key.value.rawText,
      JsonObjectKeyNull() => 'null',
      JsonObjectKeyObject() => jsonValueToString(key.value),
    };
  }
}
