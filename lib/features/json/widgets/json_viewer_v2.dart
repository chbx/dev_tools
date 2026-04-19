import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../model/json_line.dart';
import '../view_model/json_view_model.dart';
import '../view_model/view_line.dart';
import 'json_viewer_theme.dart';

/// Three-layer architecture View for the JSON viewer.
///
/// Uses SliverList.builder instead of TreeSliver.
/// Phase 3: supports collapse/expand and soft-wrap.
class JsonViewerV2 extends StatefulWidget {
  const JsonViewerV2({
    super.key,
    required this.viewModel,
    required this.themeData,
    required this.textStyle,
    required this.scrollIdH,
    required this.scrollIdV,
  });

  final JsonViewModel viewModel;
  final JsonViewerThemeData themeData;
  final TextStyle textStyle;
  final String scrollIdH;
  final String scrollIdV;

  @override
  State<JsonViewerV2> createState() => _JsonViewerV2State();
}

class _JsonViewerV2State extends State<JsonViewerV2> {
  static const double _cacheExtent = 250.0;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  /// Running maximum line width observed so far. Notifies listeners only when
  /// the value grows, so the [SizedBox] rebuilds only when needed.
  final ValueNotifier<double> _maxLineWidthNotifier = ValueNotifier<double>(0);

  /// Cached viewport height from the last LayoutBuilder pass, used by the
  /// scroll listener to compute the visible line range.
  double _lastViewportHeight = 0;
  double _lastRowHeight = 0;

  // Viewport-width synchronisation for soft-wrap.
  double _lastSyncedWidth = -1;
  bool _pendingWidthSync = false;

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_onVerticalScroll);
    widget.viewModel.addListener(_onViewModelChanged);
    widget.viewModel.scrollToViewLineNotifier.addListener(_onScrollToViewLine);
  }

  @override
  void didUpdateWidget(covariant JsonViewerV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_onViewModelChanged);
      widget.viewModel.addListener(_onViewModelChanged);
      oldWidget.viewModel.scrollToViewLineNotifier.removeListener(
        _onScrollToViewLine,
      );
      widget.viewModel.scrollToViewLineNotifier.addListener(
        _onScrollToViewLine,
      );
      _invalidateMaxWidth();
      // Reset so _syncViewportWidth re-fires for the new ViewModel.
      _lastSyncedWidth = -1;
    }
  }

  @override
  void dispose() {
    _verticalController.removeListener(_onVerticalScroll);
    widget.viewModel.removeListener(_onViewModelChanged);
    widget.viewModel.scrollToViewLineNotifier.removeListener(
      _onScrollToViewLine,
    );
    _maxLineWidthNotifier.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _onVerticalScroll() {
    // Measure newly visible lines and update the notifier if width grows.
    _measureMaxLineWidth();
  }

  void _onViewModelChanged() {
    _invalidateMaxWidth();
  }

  void _invalidateMaxWidth() {
    _maxLineWidthNotifier.value = 0;
  }

  /// Measures the visible line range and updates [_maxLineWidthNotifier]
  /// only when a wider line is found.
  void _measureMaxLineWidth() {
    final viewLines = widget.viewModel.viewLines;
    final computer = widget.viewModel.lineWidthComputer;
    final rowHeight = _lastRowHeight;
    if (rowHeight <= 0 || viewLines.isEmpty) return;

    final scrollOffset = _verticalController.hasClients
        ? _verticalController.offset
        : 0.0;

    final layoutStart = (scrollOffset - _cacheExtent).clamp(0.0, double.infinity);
    final layoutEnd = scrollOffset + _lastViewportHeight + _cacheExtent;

    final firstIndex = (layoutStart / rowHeight).floor().clamp(0, viewLines.length - 1);
    final lastIndex = (layoutEnd / rowHeight).ceil().clamp(0, viewLines.length - 1);

    double currentMax = _maxLineWidthNotifier.value;
    for (int i = firstIndex; i <= lastIndex; i++) {
      final lineWidth = computer.getLineWidth(viewLines[i]);
      if (lineWidth > currentMax) {
        currentMax = lineWidth;
      }
    }

    // ValueNotifier only notifies when value actually changes
    _maxLineWidthNotifier.value = currentMax;
  }

  void _onScrollToViewLine() {
    final viewLine = widget.viewModel.scrollToViewLineNotifier.value;
    if (viewLine < 0) return;
    if (!_verticalController.hasClients) return;

    // Defer scroll to next frame so layout (maxScrollExtent, viewport
    // dimensions) is fully up to date after the notifier fires.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) return;

      final rowHeight = widget.themeData.defaultRowHeight;
      final targetOffset = viewLine * rowHeight;
      final viewportHeight = _verticalController.position.viewportDimension;
      final centeredOffset =
          (targetOffset - viewportHeight / 2 + rowHeight / 2).clamp(
        0.0,
        _verticalController.position.maxScrollExtent,
      );

      _verticalController.animateTo(
        centeredOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );

      // ---- horizontal scroll ----
      if (!_horizontalController.hasClients) return;
      if (widget.viewModel.softWrap) return; // soft-wrap fits viewport
      final activeIdx = widget.viewModel.activeMatchIndex;
      final matches = widget.viewModel.searchMatches;
      if (activeIdx < 0 || activeIdx >= matches.length) return;
      final match = matches[activeIdx];
      final viewLines = widget.viewModel.viewLines;
      if (viewLine >= viewLines.length) return;
      final vl = viewLines[viewLine];

      // Compute character offset of this view line within its model line.
      int viewLineCharStart = 0;
      if (vl.isWrappedContinuation) {
        for (int i = viewLine - 1; i >= 0; i--) {
          final prev = viewLines[i];
          if (prev.modelLineNumber != vl.modelLineNumber) break;
          viewLineCharStart += prev.displayTokens.fold<int>(
            0,
            (sum, t) => sum + t.text.length,
          );
        }
      }
      final localCol = match.startColumn - viewLineCharStart;
      if (localCol < 0) return; // match not on this view line

      // Measure actual character width from the text style.
      final tp = TextPainter(
        text: TextSpan(text: 'm', style: widget.textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final charWidth = tp.width;

      final indentWidth = widget.themeData.prefixWidth +
          vl.modelLine.indentLevel * widget.themeData.indentWidth;
      final matchX = indentWidth + localCol * charWidth;

      final viewportWidth = _horizontalController.position.viewportDimension;
      const padding = 80.0;
      final targetLeft = matchX - padding;
      final targetRight =
          matchX + (match.endColumn - match.startColumn) * charWidth + padding;
      final currentLeft = _horizontalController.offset;
      final currentRight = currentLeft + viewportWidth;

      if (targetLeft < currentLeft || targetRight > currentRight) {
        final hOffset = (matchX - viewportWidth / 3)
            .clamp(0.0, _horizontalController.position.maxScrollExtent);
        _horizontalController.animateTo(
          hOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Deferred viewport-width sync: schedules a post-frame callback so that
  /// [JsonViewModel.updateSoftWrapConfig] (which may call notifyListeners) is
  /// never invoked during the build/layout phase.
  void _syncViewportWidth(double width) {
    if (width == _lastSyncedWidth || _pendingWidthSync) return;
    _pendingWidthSync = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pendingWidthSync = false;
      if (!mounted) return;
      _lastSyncedWidth = width;
      widget.viewModel.updateSoftWrapConfig(
        softWrap: widget.viewModel.softWrap,
        viewportWidth: width,
        textStyle: widget.textStyle,
        themeData: widget.themeData,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewLines = widget.viewModel.viewLines;
        if (viewLines.isEmpty) {
          return const SizedBox.shrink();
        }

        // ① Inject render config on every build (internally checks if changed)
        final computer = widget.viewModel.lineWidthComputer;
        final configChanged = computer.updateRenderConfig(
          baseTextStyle: widget.textStyle,
          indentWidth: widget.themeData.indentWidth,
          prefixWidth: widget.themeData.prefixWidth,
        );
        if (configChanged) {
          _invalidateMaxWidth();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final rowHeight = widget.themeData.defaultRowHeight;

            // Cache layout params for the scroll listener
            _lastViewportHeight = constraints.maxHeight;
            _lastRowHeight = rowHeight;

            // Keep the ViewModel informed about the current viewport width.
            _syncViewportWidth(constraints.maxWidth);

            // ② Measure visible lines and update notifier
            _measureMaxLineWidth();

            // ③ Only the SizedBox rebuilds when content width changes.
            return Scrollbar(
              thumbVisibility: true,
              controller: _verticalController,
              // depth == 1 because ScrollNotification travels through the
              // SingleChildScrollView wrapper before reaching this Scrollbar.
              notificationPredicate: (notification) => notification.depth == 1,
              child: Scrollbar(
                key: PageStorageKey(widget.scrollIdH),
                thumbVisibility: true,
                controller: _horizontalController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalController,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _maxLineWidthNotifier,
                    builder: (context, maxLineWidth, child) {
                      final effectiveWidth =
                          math.max(maxLineWidth + 20, constraints.maxWidth);
                      return SizedBox(
                        width: effectiveWidth,
                        height: constraints.maxHeight,
                        child: child,
                      );
                    },
                    child: SelectionArea(
                      child: DefaultTextStyle(
                        style: widget.textStyle,
                        child: CustomScrollView(
                          key: PageStorageKey(widget.scrollIdV),
                          cacheExtent: _cacheExtent,
                          scrollBehavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          controller: _verticalController,
                          slivers: [
                            if (media.padding.top > 0)
                              SliverToBoxAdapter(
                                child: SizedBox(height: media.padding.top),
                              ),
                            SliverFixedExtentList.builder(
                              itemExtent: rowHeight,
                              itemCount: viewLines.length,
                              itemBuilder: (context, index) {
                                final matchHighlights = widget.viewModel
                                    .getMatchHighlightsForViewLine(index);
                                return _JsonViewLineWidget(
                                  viewLine: viewLines[index],
                                  themeData: widget.themeData,
                                  matchHighlights: matchHighlights,
                                  onToggleCollapse:
                                      _canToggle(viewLines[index])
                                          ? () =>
                                              widget.viewModel.toggleCollapse(
                                                viewLines[index]
                                                    .modelLineNumber,
                                              )
                                          : null,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _canToggle(ViewLine vl) {
    if (vl.isWrappedContinuation) return false;
    final lt = vl.modelLine.lineType;
    return lt == JsonLineType.objectStart || lt == JsonLineType.arrayStart;
  }

  double _estimateMaxWidth(List<ViewLine> viewLines, double viewportWidth) {
    final themeData = widget.themeData;
    final isSoftWrap = widget.viewModel.softWrap;
    double maxWidth = 0;
    final sampleStep = viewLines.length > 1000 ? viewLines.length ~/ 500 : 1;

    // Measure actual character width using TextPainter for consistency
    // with the horizontal scroll calculation.
    final tp = TextPainter(
      text: TextSpan(text: 'm', style: widget.textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final charWidth = tp.width;

    for (int i = 0; i < viewLines.length; i += sampleStep) {
      final vl = viewLines[i];
      final line = vl.modelLine;
      final indentWidth =
          themeData.prefixWidth + line.indentLevel * themeData.indentWidth;

      if (isSoftWrap) {
        // When soft-wrap is on, only hint overflow can exceed the viewport.
        final displayText = vl.displayTokens.map((t) => t.text).join();
        final textWidth = displayText.length * charWidth;
        final lineWidth = indentWidth + textWidth + 20;
        maxWidth = math.max(maxWidth, lineWidth);
      } else {
        final textWidth = line.content.length * charWidth;
        final lineWidth = indentWidth + textWidth + 20;
        maxWidth = math.max(maxWidth, lineWidth);
      }
    }

    return math.max(maxWidth, viewportWidth);
  }
}

class _JsonViewLineWidget extends StatelessWidget {
  const _JsonViewLineWidget({
    required this.viewLine,
    required this.themeData,
    required this.onToggleCollapse,
    this.matchHighlights = const [],
  });

  final ViewLine viewLine;
  final JsonViewerThemeData themeData;
  final VoidCallback? onToggleCollapse;
  final List<MatchHighlight> matchHighlights;

  @override
  Widget build(BuildContext context) {
    final line = viewLine.modelLine;
    final textStyleTheme = themeData.textStyle;
    final isContainerStart =
        (line.lineType == JsonLineType.objectStart ||
            line.lineType == JsonLineType.arrayStart) &&
        !viewLine.isWrappedContinuation;
    final isCollapsed = viewLine.isCollapsedStart;

    // Base row: prefix + indent guides + text content.
    final row = Row(
      children: [
        SizedBox(width: themeData.prefixWidth),
        ..._buildIndent(line.indentLevel),
        if (isCollapsed && line.parsedFromRawText == null)
          _buildCollapsedContent(line, textStyleTheme)
        else
          Text.rich(
            TextSpan(children: _buildDisplayTokenSpans(textStyleTheme)),
          ),
      ],
    );

    if (!isContainerStart) {
      return SizedBox(height: themeData.defaultRowHeight, child: row);
    }

    // Arrow overlaid on the last indent column via Stack.
    // Text starts at prefixWidth + indentLevel * indentWidth;
    // arrow sits one indentWidth before that.
    final arrowLeft =
        themeData.prefixWidth +
        line.indentLevel * themeData.indentWidth -
        themeData.fontSize -
        2;

    return SizedBox(
      height: themeData.defaultRowHeight,
      child: Stack(
        children: [
          row,
          Positioned(
            left: arrowLeft.clamp(0, double.infinity),
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggleCollapse,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 16,
                    color: themeData.color.foldExpandButton,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the collapsed line content: key/colon rendered normally,
  /// then open bracket + " ...N " + close bracket wrapped in foldBackground.
  Widget _buildCollapsedContent(
    JsonLine line,
    JsonViewerTextStyle textStyleTheme,
  ) {
    final closeBracket = line.lineType == JsonLineType.objectStart ? '}' : ']';
    final count = line.childCount;
    final countText = count != null ? ' ...$count ' : ' ... ';

    // Find the bracket token to reuse its bracketDepth for consistent coloring.
    final bracketToken = line.tokens.whereType<JsonLineToken>().where(
      (t) => t.type == JsonTokenType.bracket,
    );
    final bracketStyle =
        bracketToken.isNotEmpty
            ? _getBracketStyle(
              textStyleTheme.brackets,
              bracketToken.first.bracketDepth,
            )
            : null;

    // Key/colon spans rendered without background.
    final prefixSpans = <InlineSpan>[];
    // Bracket + summary spans rendered with fold background.
    final foldSpans = <InlineSpan>[];

    for (final token in line.tokens) {
      if (token.type == JsonTokenType.bracket) {
        foldSpans.add(TextSpan(text: token.text, style: bracketStyle));
        break;
      }
      prefixSpans.add(
        TextSpan(
          text: token.text,
          style: _getTokenStyle(token, textStyleTheme, line.indentLevel),
        ),
      );
    }
    foldSpans.add(
      TextSpan(text: countText, style: textStyleTheme.foldForeground),
    );
    foldSpans.add(TextSpan(text: closeBracket, style: bracketStyle));

    final List<Widget> children = [];

    // Key/colon part (no background), with search highlights applied.
    if (prefixSpans.isNotEmpty) {
      final highlighted =
          matchHighlights.isEmpty ? prefixSpans : _applyHighlights(prefixSpans);
      children.add(Text.rich(TextSpan(children: highlighted)));
    }

    // Bracket + summary part (fold background, tappable with pointer cursor).
    const cursor = SystemMouseCursors.click;
    children.add(
      MouseRegion(
        cursor: cursor,
        child: DefaultSelectionStyle.merge(
          mouseCursor: cursor,
          child: GestureDetector(
            onTap: onToggleCollapse,
            behavior: HitTestBehavior.opaque,
            child: ColoredBox(
              color: themeData.color.foldBackground,
              child: Text.rich(TextSpan(children: foldSpans)),
            ),
          ),
        ),
      ),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  List<Widget> _buildIndent(int indentLevel) {
    if (indentLevel == 0) return const [];
    final border = BorderSide(width: 1, color: themeData.color.indentLine);
    return List.generate(indentLevel, (i) {
      return SizedBox(
        height: themeData.defaultRowHeight,
        width: themeData.indentWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(left: border)),
        ),
      );
    });
  }

  /// Build TextSpans from [viewLine.displayTokens] (respects soft-wrap slicing).
  List<InlineSpan> _buildDisplayTokenSpans(JsonViewerTextStyle textStyleTheme) {
    final spans =
        viewLine.displayTokens.map((token) {
          return TextSpan(
            text: token.text,
            style: _getTokenStyle(
              token,
              textStyleTheme,
              viewLine.modelLine.indentLevel,
            ),
          );
        }).toList();

    if (matchHighlights.isEmpty) return spans;
    return _applyHighlights(spans);
  }

  /// Overlay search-match highlights onto [spans].
  List<InlineSpan> _applyHighlights(List<InlineSpan> spans) {
    var result = spans;
    for (final hl in matchHighlights) {
      result = _splitSpansForHighlight(result, hl);
    }
    return result;
  }

  /// Split [spans] at the highlight boundary and apply background color.
  List<InlineSpan> _splitSpansForHighlight(
    List<InlineSpan> spans,
    MatchHighlight highlight,
  ) {
    final matchColor =
        highlight.isActive
            ? themeData.color.activeFindMatchBackground
            : themeData.color.findMatchBackground;

    final result = <InlineSpan>[];
    int charPos = 0;
    final matchStart = highlight.startColumn;
    final matchEnd = highlight.endColumn;

    for (final span in spans) {
      final text = span.toPlainText();
      final spanStart = charPos;
      final spanEnd = charPos + text.length;

      if (spanEnd <= matchStart || spanStart >= matchEnd) {
        // No overlap.
        result.add(span);
      } else {
        // There is overlap.
        final hlStart = (matchStart - spanStart).clamp(0, text.length);
        final hlEnd = (matchEnd - spanStart).clamp(0, text.length);

        if (hlStart > 0) {
          result.add(
            TextSpan(text: text.substring(0, hlStart), style: span.style),
          );
        }
        final hlStyle = (span.style ?? const TextStyle()).copyWith(
          backgroundColor: matchColor,
        );
        result.add(
          TextSpan(text: text.substring(hlStart, hlEnd), style: hlStyle),
        );
        if (hlEnd < text.length) {
          result.add(TextSpan(text: text.substring(hlEnd), style: span.style));
        }
      }
      charPos = spanEnd;
    }
    return result;
  }

  TextStyle? _getTokenStyle(
    JsonLineToken token,
    JsonViewerTextStyle textStyleTheme,
    int depth,
  ) {
    return switch (token.type) {
      JsonTokenType.key => textStyleTheme.objectKey,
      JsonTokenType.colon => textStyleTheme.colon,
      JsonTokenType.string => textStyleTheme.string,
      JsonTokenType.number => textStyleTheme.number,
      JsonTokenType.literal => textStyleTheme.literal,
      JsonTokenType.bracket => _getBracketStyle(
        textStyleTheme.brackets,
        token.bracketDepth,
      ),
      JsonTokenType.comma => textStyleTheme.comma,
      JsonTokenType.hint => textStyleTheme.hint,
    };
  }

  TextStyle? _getBracketStyle(List<TextStyle>? brackets, int depth) {
    if (brackets == null || brackets.isEmpty) return null;
    return brackets[depth % brackets.length];
  }
}
