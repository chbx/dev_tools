import '../model/json_line.dart';

/// A view-line projected from a [JsonLine].
class ViewLine {
  final int viewLineNumber;
  final int modelLineNumber;
  final JsonLine modelLine;

  /// `true` when this line is a container-start whose body is collapsed.
  final bool isCollapsedStart;

  /// `true` when this view line is a continuation of a soft-wrapped model line
  /// (i.e. the 2nd, 3rd, ... visual line produced by a single model line).
  final bool isWrappedContinuation;

  /// Tokens to render on this specific view line.
  ///
  /// For non-wrapped lines this equals [modelLine.tokens].
  /// For wrapped lines this is a subset / slice of the original tokens.
  final List<JsonLineToken> displayTokens;

  /// Non-null when this view line was emitted as part of a `$ref` expansion.
  /// Stores the original container-start line number so the UI can toggle
  /// the ref-expand state back.
  final int? refSourceLineNumber;

  ViewLine({
    required this.viewLineNumber,
    required this.modelLineNumber,
    required this.modelLine,
    this.isCollapsedStart = false,
    this.isWrappedContinuation = false,
    this.refSourceLineNumber,
    List<JsonLineToken>? displayTokens,
  }) : displayTokens = displayTokens ?? modelLine.tokens;
}
