import '../model/json_line.dart';

/// A view-line projected from a [JsonLine].
class ViewLine {
  // TODO: redundant with modelLineNumber in Phase 1, meaningful after Phase 3 soft-wrap
  final int viewLineNumber;
  final int modelLineNumber;
  final JsonLine modelLine;

  /// `true` when this line is a container-start whose body is collapsed.
  final bool isCollapsedStart;

  const ViewLine({
    required this.viewLineNumber,
    required this.modelLineNumber,
    required this.modelLine,
    this.isCollapsedStart = false,
  });
}
