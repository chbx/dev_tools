import 'package:flutter/foundation.dart';

import '../model/json_model.dart';
import '../service/line_width_computer.dart';
import 'view_line.dart';

/// Maps Model lines to View lines.
class JsonViewModel extends ChangeNotifier {
  JsonModel? _model;

  List<ViewLine> _viewLines = const [];
  List<ViewLine> get viewLines => _viewLines;

  /// Width calculator, held by ViewModel, render config injected by View layer.
  final LineWidthComputer lineWidthComputer = LineWidthComputer();

  void updateModel(JsonModel? model) {
    _model = model;
    rebuildViewLines();
  }

  void rebuildViewLines() {
    final model = _model;
    if (model == null) {
      _viewLines = const [];
      notifyListeners();
      return;
    }

    _viewLines = List.generate(model.lines.length, (i) {
      final line = model.lines[i];
      return ViewLine(
        viewLineNumber: i,
        modelLineNumber: line.lineNumber,
        modelLine: line,
      );
    });

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
