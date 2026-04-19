import 'package:flutter/painting.dart';

import '../model/json_line.dart';

/// Computes soft-wrap line breaks for a single model line's tokens.
///
/// Only "main" tokens (everything except [JsonTokenType.hint]) participate in
/// the wrapping calculation.  Hint tokens are appended to the **last** visual
/// line so they can overflow the viewport and be handled by horizontal scroll.
class LineBreakComputer {
  /// Compute line breaks for [tokens] given [availableWidth].
  ///
  /// Returns a list where each element is the [JsonLineToken] list for one
  /// visual (view) line.  A single-element result means no wrapping occurred.
  ///
  /// [styleResolver] maps a token to its Flutter [TextStyle] so that the
  /// [TextPainter] measurement matches the actual rendering.
  static List<List<JsonLineToken>> compute({
    required List<JsonLineToken> tokens,
    required double availableWidth,
    required TextStyle baseStyle,
    required TextStyle? Function(JsonLineToken token) styleResolver,
  }) {
    if (tokens.isEmpty || availableWidth <= 0) {
      return [tokens];
    }

    // Separate main tokens from hint tokens.
    final mainTokens = <JsonLineToken>[];
    final hintTokens = <JsonLineToken>[];
    for (final t in tokens) {
      if (t.type == JsonTokenType.hint) {
        hintTokens.add(t);
      } else {
        mainTokens.add(t);
      }
    }

    if (mainTokens.isEmpty) {
      return [tokens];
    }

    // Build a styled TextSpan that mirrors the rendering output.
    final spans = mainTokens.map((t) {
      final style = styleResolver(t);
      return TextSpan(text: t.text, style: style);
    }).toList();

    final painter = TextPainter(
      text: TextSpan(children: spans, style: baseStyle),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: availableWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.length <= 1) {
      // No wrapping needed – return all tokens (main + hint) as a single line.
      painter.dispose();
      return [tokens];
    }

    // Collect character ranges for each visual line.
    final lineRanges = <TextRange>[];
    for (int i = 0; i < metrics.length; i++) {
      // Pick a y-coordinate inside the line to query its boundary.
      final y = metrics[i].baseline - metrics[i].ascent + 1;
      final pos = painter.getPositionForOffset(Offset(0, y));
      final range = painter.getLineBoundary(pos);
      lineRanges.add(range);
    }
    painter.dispose();

    // Slice main tokens according to character ranges.
    final result = <List<JsonLineToken>>[];
    for (int i = 0; i < lineRanges.length; i++) {
      final range = lineRanges[i];
      final sliced = sliceTokens(mainTokens, range.start, range.end);
      if (i == lineRanges.length - 1) {
        // Append hint tokens to the last visual line.
        sliced.addAll(hintTokens);
      }
      result.add(sliced);
    }

    return result;
  }

  /// Slice [tokens] to keep only the characters in the half-open range
  /// `[charStart, charEnd)`.
  ///
  /// Tokens that fall entirely outside the range are dropped.  Tokens that
  /// straddle a boundary are substring-ed and retain their original
  /// [JsonTokenType] and [JsonLineToken.bracketDepth].
  static List<JsonLineToken> sliceTokens(
    List<JsonLineToken> tokens,
    int charStart,
    int charEnd,
  ) {
    final result = <JsonLineToken>[];
    int pos = 0;
    for (final token in tokens) {
      final tokenEnd = pos + token.text.length;
      if (tokenEnd <= charStart) {
        pos = tokenEnd;
        continue;
      }
      if (pos >= charEnd) break;

      final sliceStart = (charStart - pos).clamp(0, token.text.length);
      final sliceEnd = (charEnd - pos).clamp(0, token.text.length);
      if (sliceStart < sliceEnd) {
        result.add(JsonLineToken(
          token.text.substring(sliceStart, sliceEnd),
          token.type,
          bracketDepth: token.bracketDepth,
        ));
      }
      pos = tokenEnd;
    }
    return result;
  }
}
