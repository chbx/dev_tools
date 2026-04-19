import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/json_line.dart';
import '../view_model/view_line.dart';

/// Width calculation and cache management class, held by ViewModel but render config is injected by View layer.
class LineWidthComputer {
  // ── Render config (injected by View layer) ──
  TextStyle _baseTextStyle = const TextStyle();
  double _indentWidth = 0;
  double _prefixWidth = 0;

  // ── Monospace font character width cache ──
  double _monoCharWidth = 0;

  // ── Line width cache: modelLineNumber → width ──
  final Map<int, double> _cache = {};

  // ── TextPainter reuse (slow path) ──
  TextPainter? _textPainter;

  /// Called by View layer during build to inject/update render config.
  /// [baseTextStyle] should match the [DefaultTextStyle] used for rendering,
  /// so that width measurement accounts for letterSpacing, wordSpacing, etc.
  /// Automatically clears all cache when config changes.
  /// Returns `true` if the config actually changed, `false` otherwise.
  bool updateRenderConfig({
    required TextStyle baseTextStyle,
    required double indentWidth,
    required double prefixWidth,
  }) {
    if (_baseTextStyle == baseTextStyle &&
        _indentWidth == indentWidth &&
        _prefixWidth == prefixWidth) {
      return false;
    }

    _baseTextStyle = baseTextStyle;
    _indentWidth = indentWidth;
    _prefixWidth = prefixWidth;

    // Recalculate monospace character width
    _monoCharWidth = _measureMonoCharWidth();

    // Config changed → invalidate all cache
    invalidateAll();
    return true;
  }

  /// Gets the pixel width of a single line (including indent and prefix).
  /// Reads from cache first; calculates and caches on miss.
  double getLineWidth(ViewLine viewLine) {
    final key = viewLine.modelLineNumber;
    final cached = _cache[key];
    if (cached != null) return cached;

    final width = _computeLineWidth(viewLine);
    _cache[key] = width;
    return width;
  }

  /// Invalidates cache for a specified range (used during fold/expand).
  void invalidateRange(int startModelLine, int endModelLine) {
    for (int i = startModelLine; i <= endModelLine; i++) {
      _cache.remove(i);
    }
  }

  /// Invalidates all cache (used when font/theme changes).
  void invalidateAll() {
    _cache.clear();
    _textPainter?.dispose();
    _textPainter = null;
  }

  /// Releases resources.
  void dispose() {
    _cache.clear();
    _textPainter?.dispose();
    _textPainter = null;
  }

  // ── Internal calculation methods ──

  double _computeLineWidth(ViewLine viewLine) {
    final line = viewLine.modelLine;
    final indentPixels = _prefixWidth + line.indentLevel * _indentWidth;

    if (line.isBasicASCII) {
      return _computeFast(line, indentPixels);
    } else {
      return _computeFull(line, indentPixels);
    }
  }

  /// Fast path: pure ASCII + monospace font → pure math calculation.
  double _computeFast(JsonLine line, double indentPixels) {
    final textWidth = _computeTokensWidthFast(line.tokens);
    return indentPixels + textWidth;
  }

  /// Fast calculation of total text width for all tokens.
  double _computeTokensWidthFast(List<JsonLineToken> tokens) {
    int totalChars = 0;
    for (final token in tokens) {
      totalChars += token.text.length;
    }
    return totalChars * _monoCharWidth;
  }

  /// Full path: actual width measurement via TextPainter.
  double _computeFull(JsonLine line, double indentPixels) {
    final textWidth = _measureTokensWidth(line.tokens);
    return indentPixels + textWidth;
  }

  /// Measures actual render width of tokens using TextPainter.
  double _measureTokensWidth(List<JsonLineToken> tokens) {
    final spans = tokens.map((token) {
      return TextSpan(text: token.text, style: _baseTextStyle);
    }).toList();

    _textPainter ??= TextPainter(textDirection: ui.TextDirection.ltr);
    _textPainter!.text = TextSpan(children: spans);
    _textPainter!.layout();
    return _textPainter!.width;
  }

  /// Measures pixel width of a single character in monospace font.
  /// Uses "x" as reference character (similar to VS Code's typicalHalfwidthCharacterWidth).
  double _measureMonoCharWidth() {
    final painter = TextPainter(
      text: TextSpan(text: 'x', style: _baseTextStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
