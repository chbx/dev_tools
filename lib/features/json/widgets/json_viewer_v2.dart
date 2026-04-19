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
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // Cached content width to avoid recomputation on every rebuild.
  double _cachedContentWidth = 0;
  int _cachedViewLinesLength = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedViewLinesLength = -1;
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
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

        return LayoutBuilder(
          builder: (context, constraints) {
            if (viewLines.length != _cachedViewLinesLength) {
              _cachedContentWidth = _estimateMaxWidth(viewLines, constraints.maxWidth);
              _cachedViewLinesLength = viewLines.length;
            }
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
                  child: SizedBox(
                    width: _cachedContentWidth,
                    height: constraints.maxHeight,
                    child: SelectionArea(
                      child: DefaultTextStyle(
                        style: widget.textStyle,
                        child: CustomScrollView(
                          key: PageStorageKey(widget.scrollIdV),
                          scrollBehavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          controller: _verticalController,
                          slivers: [
                            if (media.padding.top > 0)
                              SliverToBoxAdapter(
                                child: SizedBox(height: media.padding.top),
                              ),
                            SliverFixedExtentList.builder(
                              itemExtent: widget.themeData.defaultRowHeight,
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

  // TODO
  double _estimateMaxWidth(List<ViewLine> viewLines, double viewportWidth) {
    final themeData = widget.themeData;
    double maxWidth = 0;
    final sampleStep = viewLines.length > 1000 ? viewLines.length ~/ 500 : 1;

    for (int i = 0; i < viewLines.length; i += sampleStep) {
      final line = viewLines[i].modelLine;
      final indentWidth = themeData.prefixWidth + line.indentLevel * themeData.indentWidth;
      final charWidth = themeData.fontSize * 0.6;
      final textWidth = line.content.length * charWidth;
      final lineWidth = indentWidth + textWidth + 20;
      maxWidth = math.max(maxWidth, lineWidth);
    }

    return math.max(maxWidth, viewportWidth);
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
