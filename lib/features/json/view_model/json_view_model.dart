import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/json_line.dart';
import '../model/json_model.dart';
import '../service/line_width_computer.dart';
import '../widgets/json_viewer_theme.dart';
import 'line_break_computer.dart';
import 'view_line.dart';

/// Maps Model lines to View lines, filtering out collapsed ranges.
///
/// Supports soft-wrap: when enabled a single model line may produce multiple
/// view lines.  A prefix-sum array enables O(1) model→view and O(log n)
/// view→model coordinate conversion.
class JsonViewModel extends ChangeNotifier {
  JsonModel? _model;

  JsonModel? get model => _model;

  List<ViewLine> _viewLines = const [];

  List<ViewLine> get viewLines => _viewLines;

  /// Width calculator, held by ViewModel, render config injected by View layer.
  final LineWidthComputer lineWidthComputer = LineWidthComputer();

  // ---- soft-wrap configuration ----

  bool _softWrap = false;

  bool get softWrap => _softWrap;

  double _viewportWidth = double.infinity;
  TextStyle? _textStyle;
  JsonViewerThemeData? _themeData;

  /// Prefix sums for model→view line mapping.
  ///
  /// `_prefixSums[i]` = total number of view lines produced by the first `i`
  /// visible model lines (after collapse filtering).  `_prefixSums[0] == 0`.
  List<int> _prefixSums = const [];

  /// Number of view lines each visible model line expands into.
  List<int> get viewLineCountPerModelLine => _viewLineCountPerModelLine;
  List<int> _viewLineCountPerModelLine = const [];

  // ---- public API ----

  void updateModel(JsonModel? model) {
    _model = model;
    rebuildViewLines();
  }

  /// Update soft-wrap configuration.  Triggers a rebuild only when something
  /// actually changed.
  void updateSoftWrapConfig({
    required bool softWrap,
    required double viewportWidth,
    required TextStyle textStyle,
    required JsonViewerThemeData themeData,
  }) {
    final changed =
        softWrap != _softWrap ||
        viewportWidth != _viewportWidth ||
        textStyle != _textStyle ||
        !identical(themeData, _themeData);
    _softWrap = softWrap;
    _viewportWidth = viewportWidth;
    _textStyle = textStyle;
    _themeData = themeData;
    if (changed) {
      rebuildViewLines();
    }
  }

  /// Toggle soft-wrap on/off and rebuild.
  void toggleSoftWrap() {
    _softWrap = !_softWrap;
    rebuildViewLines();
  }

  /// Toggle collapse on a container-start line and rebuild.
  void toggleCollapse(int modelLineNumber) {
    final model = _model;
    if (model == null) return;
    if (model.toggleCollapse(modelLineNumber)) {
      rebuildViewLines();
    }
  }

  /// Collapse all containers and rebuild.
  void collapseAll() {
    final model = _model;
    if (model == null) return;
    model.collapseAll();
    rebuildViewLines();
  }

  /// Expand all containers and rebuild.
  void expandAll() {
    final model = _model;
    if (model == null) return;
    model.expandAll();
    rebuildViewLines();
  }

  // ---- coordinate conversion ----

  /// Model visible-line index → first View line number.  O(1).
  int modelToViewLineNumber(int visibleModelIndex) {
    if (visibleModelIndex < 0 || visibleModelIndex >= _prefixSums.length - 1) {
      return 0;
    }
    return _prefixSums[visibleModelIndex];
  }

  /// View line number → visible-model-line index.  O(log n).
  int viewToModelLineNumber(int viewLineNumber) {
    // Binary-search for the last prefix sum ≤ viewLineNumber.
    int lo = 0;
    int hi = _prefixSums.length - 2; // last valid index
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_prefixSums[mid] <= viewLineNumber) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  // ---- rebuild ----

  void rebuildViewLines() {
    final model = _model;
    if (model == null) {
      _viewLines = const [];
      _prefixSums = const [];
      _viewLineCountPerModelLine = const [];
      notifyListeners();
      return;
    }

    final lines = model.lines;
    final collapsed = model.collapsedLineNumbers;
    final startToEnd = model.startToEndMap;

    final doWrap = _softWrap && _themeData != null && _textStyle != null;

    final result = <ViewLine>[];
    final perModelCounts = <int>[];
    int viewLineNum = 0;
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (collapsed.contains(line.lineNumber)) {
        final endLineNumber = startToEnd[line.lineNumber];
        final isParsed = line.parsedFromRawText != null;

        if (isParsed) {
          // Collapsed parsed container: build virtual tokens (key+rawText)
          // so it renders as a plain string and supports soft-wrap.
          final virtualTokens = _buildParsedCollapsedTokens(line);

          if (doWrap) {
            final wrapResults = _computeWrappedLinesFromTokens(
              line,
              virtualTokens,
            );
            for (int w = 0; w < wrapResults.length; w++) {
              result.add(
                ViewLine(
                  viewLineNumber: viewLineNum++,
                  modelLineNumber: line.lineNumber,
                  modelLine: line,
                  isCollapsedStart: true,
                  isWrappedContinuation: w > 0,
                  displayTokens: wrapResults[w],
                ),
              );
            }
            perModelCounts.add(wrapResults.length);
          } else {
            result.add(
              ViewLine(
                viewLineNumber: viewLineNum++,
                modelLineNumber: line.lineNumber,
                modelLine: line,
                isCollapsedStart: true,
                displayTokens: virtualTokens,
              ),
            );
            perModelCounts.add(1);
          }
        } else {
          // Normal collapsed container: single view line.
          result.add(
            ViewLine(
              viewLineNumber: viewLineNum++,
              modelLineNumber: line.lineNumber,
              modelLine: line,
              isCollapsedStart: true,
            ),
          );
          perModelCounts.add(1);
        }
        if (endLineNumber != null) {
          i = endLineNumber + 1;
        } else {
          i++;
        }
      } else if (doWrap) {
        // Soft-wrap: compute line breaks.
        final wrapResults = _computeWrappedLines(line);
        for (int w = 0; w < wrapResults.length; w++) {
          result.add(
            ViewLine(
              viewLineNumber: viewLineNum++,
              modelLineNumber: line.lineNumber,
              modelLine: line,
              isWrappedContinuation: w > 0,
              displayTokens: wrapResults[w],
            ),
          );
        }
        perModelCounts.add(wrapResults.length);
        i++;
      } else {
        // No wrapping.
        result.add(
          ViewLine(
            viewLineNumber: viewLineNum++,
            modelLineNumber: line.lineNumber,
            modelLine: line,
          ),
        );
        perModelCounts.add(1);
        i++;
      }
    }

    _viewLines = result;
    _viewLineCountPerModelLine = perModelCounts;
    _buildPrefixSums(perModelCounts);

    // Line structure changed → invalidate all cache
    lineWidthComputer.invalidateAll();
    notifyListeners();
  }

  @override
  void dispose() {
    lineWidthComputer.dispose();
    super.dispose();
  }

  // ---- private helpers ----

  /// Build virtual display tokens for a collapsed parsed container:
  /// key/colon prefix from the original line + the raw string text.
  List<JsonLineToken> _buildParsedCollapsedTokens(JsonLine line) {
    final tokens = <JsonLineToken>[];
    for (final token in line.tokens) {
      if (token.type == JsonTokenType.bracket) break;
      tokens.add(token);
    }
    tokens.add(
      JsonLineToken(line.parsedFromRawText!, JsonTokenType.string),
    );
    return tokens;
  }

  List<List<JsonLineToken>> _computeWrappedLinesFromTokens(
    JsonLine line,
    List<JsonLineToken> tokens,
  ) {
    final themeData = _themeData!;
    final textStyle = _textStyle!;
    final indentArea =
        themeData.prefixWidth + line.indentLevel * themeData.indentWidth;
    final availableWidth = (_viewportWidth - indentArea).clamp(
      80.0,
      double.infinity,
    );

    return LineBreakComputer.compute(
      tokens: tokens,
      availableWidth: availableWidth,
      baseStyle: textStyle,
      styleResolver:
          (token) => _resolveTokenStyle(token, themeData, line.indentLevel),
    );
  }

  List<List<JsonLineToken>> _computeWrappedLines(JsonLine line) {
    final themeData = _themeData!;
    final textStyle = _textStyle!;
    final indentArea =
        themeData.prefixWidth + line.indentLevel * themeData.indentWidth;
    final availableWidth = (_viewportWidth - indentArea).clamp(
      80.0,
      double.infinity,
    );

    return LineBreakComputer.compute(
      tokens: line.tokens,
      availableWidth: availableWidth,
      baseStyle: textStyle,
      styleResolver:
          (token) => _resolveTokenStyle(token, themeData, line.indentLevel),
    );
  }

  TextStyle? _resolveTokenStyle(
    JsonLineToken token,
    JsonViewerThemeData themeData,
    int depth,
  ) {
    final ts = themeData.textStyle;
    return switch (token.type) {
      JsonTokenType.key => ts.objectKey,
      JsonTokenType.colon => ts.colon,
      JsonTokenType.string => ts.string,
      JsonTokenType.number => ts.number,
      JsonTokenType.literal => ts.literal,
      JsonTokenType.bracket => _getBracketStyle(
        ts.brackets,
        token.bracketDepth,
      ),
      JsonTokenType.comma => ts.comma,
      JsonTokenType.hint => ts.hint,
    };
  }

  static TextStyle? _getBracketStyle(List<TextStyle>? brackets, int depth) {
    if (brackets == null || brackets.isEmpty) return null;
    return brackets[depth % brackets.length];
  }

  void _buildPrefixSums(List<int> counts) {
    final sums = List<int>.filled(counts.length + 1, 0);
    for (int i = 0; i < counts.length; i++) {
      sums[i + 1] = sums[i] + counts[i];
    }
    _prefixSums = sums;
  }
}
