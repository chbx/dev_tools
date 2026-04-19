import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/json_line.dart';
import '../model/json_model.dart';
import '../service/line_width_computer.dart';
import '../widgets/json_viewer_theme.dart';
import 'line_break_computer.dart';
import 'view_line.dart';

/// A highlight range within a single view line.
class MatchHighlight {
  final int startColumn; // character offset within the view-line text
  final int endColumn;
  final bool isActive;

  const MatchHighlight({
    required this.startColumn,
    required this.endColumn,
    required this.isActive,
  });
}

/// Maps Model lines to View lines, filtering out collapsed ranges.
///
/// Supports soft-wrap: when enabled a single model line may produce multiple
/// view lines.  A prefix-sum array enables O(1) model→view and O(log n)
/// view→model coordinate conversion.
class JsonViewModel extends ChangeNotifier {
  JsonModel? _model;

  JsonModel? get model => _model;

  // ---- search state ----

  List<ModelSearchMatch> _searchMatches = const [];
  int _activeMatchIndex = -1;

  /// Model line number → index in _visibleModelLines (built during rebuildViewLines).
  Map<int, int> _modelLineToVisibleIndex = const {};

  /// Per-visible-model-line: its model line number (built during rebuildViewLines).
  // ignore: unused_field
  List<int> _visibleModelLineNumbers = const [];

  /// Notifier that fires when the view should scroll to a specific view line.
  final ValueNotifier<int> scrollToViewLineNotifier = ValueNotifier<int>(-1);

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
    final modelLineToVisible = <int, int>{};
    final visibleModelLines = <int>[];
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
          modelLineToVisible[line.lineNumber] = visibleModelLines.length;
          visibleModelLines.add(line.lineNumber);
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
          modelLineToVisible[line.lineNumber] = visibleModelLines.length;
          visibleModelLines.add(line.lineNumber);
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
        modelLineToVisible[line.lineNumber] = visibleModelLines.length;
        visibleModelLines.add(line.lineNumber);
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
        modelLineToVisible[line.lineNumber] = visibleModelLines.length;
        visibleModelLines.add(line.lineNumber);
        i++;
      }
    }

    _viewLines = result;
    _modelLineToVisibleIndex = modelLineToVisible;
    _visibleModelLineNumbers = visibleModelLines;
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

  // ---- search API ----

  /// Replace the current search matches and notify listeners.
  void updateSearchMatches(List<ModelSearchMatch> matches) {
    _searchMatches = matches;
    _activeMatchIndex = matches.isEmpty ? -1 : 0;
    notifyListeners();
  }

  /// Clear search matches.
  void clearSearchMatches() {
    _searchMatches = const [];
    _activeMatchIndex = -1;
    notifyListeners();
  }

  /// Whether [setActiveMatchIndex] expanded collapsed containers on its last
  /// call.  When `true` the caller should defer the scroll to a post-frame
  /// callback so that the layout reflects the newly expanded lines.
  bool didExpandForLastMatch = false;

  /// Set the active match by index. Returns the view line number to scroll to,
  /// or -1 if the match is not visible.
  ///
  /// If the match is inside a collapsed region, the enclosing containers are
  /// automatically expanded and view lines are rebuilt before computing the
  /// scroll target.  In that case [didExpandForLastMatch] is set to `true`.
  int setActiveMatchIndex(int index) {
    _activeMatchIndex = index;
    didExpandForLastMatch = false;
    if (index < 0 || index >= _searchMatches.length) {
      notifyListeners();
      return -1;
    }
    final match = _searchMatches[index];

    // If the target line is inside a collapsed region, expand it first.
    final model = _model;
    if (model != null &&
        _modelLineToVisibleIndex[match.lineNumber] == null) {
      if (model.expandContainersOf(match.lineNumber)) {
        didExpandForLastMatch = true;
        rebuildViewLines(); // rebuilds _modelLineToVisibleIndex
        // notifyListeners() was already called by rebuildViewLines
        return _getViewLineForMatch(match);
      }
    }

    notifyListeners();
    return _getViewLineForMatch(match);
  }

  int get activeMatchIndex => _activeMatchIndex;

  List<ModelSearchMatch> get searchMatches => _searchMatches;

  /// Returns the view line number that contains [match], accounting for
  /// soft-wrap. Returns -1 if the model line is not visible (collapsed).
  int _getViewLineForMatch(ModelSearchMatch match) {
    final visibleIndex = _modelLineToVisibleIndex[match.lineNumber];
    if (visibleIndex == null) return -1;
    final firstViewLine = modelToViewLineNumber(visibleIndex);
    // Walk through the view lines of this model line to find the one
    // that contains match.startColumn.
    int charOffset = 0;
    for (int vl = firstViewLine; vl < _viewLines.length; vl++) {
      final viewLine = _viewLines[vl];
      if (viewLine.modelLineNumber != match.lineNumber) break;
      final lineCharLen = viewLine.displayTokens.fold<int>(
        0,
        (sum, t) => sum + t.text.length,
      );
      if (match.startColumn < charOffset + lineCharLen) {
        return vl;
      }
      charOffset += lineCharLen;
    }
    // Fallback: return the first view line.
    return firstViewLine;
  }

  /// Returns highlight ranges for a given view line.
  List<MatchHighlight> getMatchHighlightsForViewLine(int viewLineIndex) {
    if (_searchMatches.isEmpty ||
        viewLineIndex < 0 ||
        viewLineIndex >= _viewLines.length) {
      return const [];
    }
    final vl = _viewLines[viewLineIndex];
    final modelLineNumber = vl.modelLineNumber;

    // Compute the character offset of this view line within the model line.
    // For wrapped continuation lines, we need to sum the lengths of previous
    // view-line slices belonging to the same model line.
    int viewLineCharStart = 0;
    if (vl.isWrappedContinuation) {
      // Walk backwards to find the first view line of this model line.
      for (int i = viewLineIndex - 1; i >= 0; i--) {
        final prev = _viewLines[i];
        if (prev.modelLineNumber != modelLineNumber) break;
        viewLineCharStart += prev.displayTokens.fold<int>(
          0,
          (sum, t) => sum + t.text.length,
        );
      }
    }
    final viewLineCharLen = vl.displayTokens.fold<int>(
      0,
      (sum, t) => sum + t.text.length,
    );
    final viewLineCharEnd = viewLineCharStart + viewLineCharLen;

    final highlights = <MatchHighlight>[];
    for (int mi = 0; mi < _searchMatches.length; mi++) {
      final m = _searchMatches[mi];
      if (m.lineNumber != modelLineNumber) continue;
      // Clip match range to this view line's character range.
      final clippedStart = m.startColumn.clamp(
        viewLineCharStart,
        viewLineCharEnd,
      );
      final clippedEnd = m.endColumn.clamp(viewLineCharStart, viewLineCharEnd);
      if (clippedStart >= clippedEnd) continue;
      highlights.add(
        MatchHighlight(
          startColumn: clippedStart - viewLineCharStart,
          endColumn: clippedEnd - viewLineCharStart,
          isActive: mi == _activeMatchIndex,
        ),
      );
    }
    return highlights;
  }
}
