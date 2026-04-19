import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/json_line.dart';
import '../view_model/json_view_model.dart';
import '../view_model/view_line.dart';
import 'json_viewer_theme.dart';

/// Three-layer architecture View for the JSON viewer.
///
/// Uses SliverList.builder instead of TreeSliver.
/// Phase 1: basic rendering skeleton, fully expanded, no collapse/search.
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

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_onVerticalScroll);
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void didUpdateWidget(covariant JsonViewerV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_onViewModelChanged);
      widget.viewModel.addListener(_onViewModelChanged);
      _invalidateMaxWidth();
    }
  }

  @override
  void dispose() {
    _verticalController.removeListener(_onVerticalScroll);
    widget.viewModel.removeListener(_onViewModelChanged);
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
                                return _JsonViewLineWidget(
                                  viewLine: viewLines[index],
                                  themeData: widget.themeData,
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
}

class _JsonViewLineWidget extends StatelessWidget {
  const _JsonViewLineWidget({
    required this.viewLine,
    required this.themeData,
  });

  final ViewLine viewLine;
  final JsonViewerThemeData themeData;

  @override
  Widget build(BuildContext context) {
    final line = viewLine.modelLine;
    final textStyleTheme = themeData.textStyle;

    return SizedBox(
      height: themeData.defaultRowHeight,
      child: Row(
        children: [
          SizedBox(width: themeData.prefixWidth),
          ..._buildIndent(line.indentLevel),
          Text.rich(
            TextSpan(children: _buildTokenSpans(line, textStyleTheme)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIndent(int indentLevel) {
    if (indentLevel == 0) return const [];
    final border = BorderSide(width: 1, color: themeData.color.indentLine);
    return List.generate(indentLevel, (i) {
      return SizedBox(
        height: themeData.defaultRowHeight,
        width: themeData.indentWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: border),
          ),
        ),
      );
    });
  }

  List<InlineSpan> _buildTokenSpans(
    JsonLine line,
    JsonViewerTextStyle textStyleTheme,
  ) {
    return line.tokens.map((token) {
      return TextSpan(
        text: token.text,
        style: _getTokenStyle(token, textStyleTheme, line.indentLevel),
      );
    }).toList();
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
