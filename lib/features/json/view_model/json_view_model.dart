import 'package:flutter/foundation.dart';

import '../model/json_model.dart';
import '../service/line_width_computer.dart';
import 'view_line.dart';

/// Maps Model lines to View lines, filtering out collapsed ranges.
class JsonViewModel extends ChangeNotifier {
  JsonModel? _model;
  JsonModel? get model => _model;

  List<ViewLine> _viewLines = const [];
  List<ViewLine> get viewLines => _viewLines;

  /// Width calculator, held by ViewModel, render config injected by View layer.
  final LineWidthComputer lineWidthComputer = LineWidthComputer();

  void updateModel(JsonModel? model) {
    _model = model;
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

  void rebuildViewLines() {
    final model = _model;
    if (model == null) {
      _viewLines = const [];
      notifyListeners();
      return;
    }

    final lines = model.lines;
    final collapsed = model.collapsedLineNumbers;
    final startToEnd = model.startToEndMap;

    final result = <ViewLine>[];
    int viewLineNum = 0;
    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (collapsed.contains(line.lineNumber)) {
        // Show the start line but mark it collapsed; skip inner + end lines.
        result.add(ViewLine(
          viewLineNumber: viewLineNum++,
          modelLineNumber: line.lineNumber,
          modelLine: line,
          isCollapsedStart: true,
        ));
        final endLineNumber = startToEnd[line.lineNumber];
        if (endLineNumber != null) {
          // Jump past the matching end line.
          // Lines are stored in order, so find the index of endLineNumber.
          // Since lineNumber == index in the current builder, we can jump directly.
          i = endLineNumber + 1;
        } else {
          i++;
        }
      } else {
        result.add(ViewLine(
          viewLineNumber: viewLineNum++,
          modelLineNumber: line.lineNumber,
          modelLine: line,
        ));
        i++;
      }
    }

    _viewLines = result;

    // Line structure changed → invalidate all cache
    lineWidthComputer.invalidateAll();
    notifyListeners();
  }

  @override
  void dispose() {
    lineWidthComputer.dispose();
    super.dispose();
  }
}
