import 'dart:collection';

import '../utils/line_builder.dart';
import 'json_line.dart';
import 'json_value.dart';

/// Holds the parsed JSON tree and its flattened line representation.
///
/// `versionId` is incremented on fold/expand (Phase 2) to signal ViewModel rebuild.
class JsonModel {
  final JsonValue rootValue;
  final UnmodifiableListView<JsonLine> lines;
  int versionId;

  JsonModel._({
    required this.rootValue,
    required this.lines,
    this.versionId = 0, // ignore: unused_element_parameter
  });

  factory JsonModel.fromJsonValue(JsonValue rootValue) {
    final lines = buildJsonLines(rootValue);
    return JsonModel._(rootValue: rootValue, lines: UnmodifiableListView(lines));
  }
}
