import 'dart:collection';

import '../utils/line_builder.dart';
import 'json_line.dart';
import 'json_value.dart';

/// A search match in Model coordinate system.
class ModelSearchMatch {
  final int lineNumber; // model line number (0-based)
  final int startColumn; // character offset in line.content
  final int endColumn;

  const ModelSearchMatch({
    required this.lineNumber,
    required this.startColumn,
    required this.endColumn,
  });
}

/// Holds the parsed JSON tree and its flattened line representation.
///
/// Manages collapse/expand state for container lines (objectStart / arrayStart).
class JsonModel {
  final JsonValue rootValue;
  final UnmodifiableListView<JsonLine> lines;

  /// Maps a container-start line number to its matching end line number.
  final Map<int, int> startToEndMap;

  /// Set of line numbers whose containers are currently collapsed.
  final Set<int> collapsedLineNumbers;

  /// Line numbers of container-start lines generated from parsed nested JSON
  /// strings.  These are collapsed by default and skipped by [expandAll].
  final Set<int> parsedContainerLineNumbers;

  int versionId;

  JsonModel._(
      {required this.rootValue,
      required this.lines,
      required this.startToEndMap,
      required this.parsedContainerLineNumbers,
      Set<int>? collapsedLineNumbers,
      this.versionId = 0 // ignore: unused_element_parameter
      })
      : collapsedLineNumbers = collapsedLineNumbers ?? {};

  factory JsonModel.fromJsonValue(JsonValue rootValue) {
    final lines = buildJsonLines(rootValue);
    final startToEnd = _buildStartToEndMap(lines);
    final parsedContainers = <int>{};
    final defaultCollapsed = <int>{};
    for (final line in lines) {
      if (line.parsedFromRawText != null) {
        parsedContainers.add(line.lineNumber);
        defaultCollapsed.add(line.lineNumber);
      }
    }
    return JsonModel._(
      rootValue: rootValue,
      lines: UnmodifiableListView(lines),
      startToEndMap: startToEnd,
      parsedContainerLineNumbers: parsedContainers,
      collapsedLineNumbers: defaultCollapsed,
    );
  }

  /// Toggle the collapse state of a container-start line.
  /// Returns `true` if the state changed.
  bool toggleCollapse(int lineNumber) {
    if (!startToEndMap.containsKey(lineNumber)) return false;
    if (collapsedLineNumbers.contains(lineNumber)) {
      collapsedLineNumbers.remove(lineNumber);
    } else {
      collapsedLineNumbers.add(lineNumber);
    }
    versionId++;
    return true;
  }

  /// Collapse all container-start lines.
  void collapseAll() {
    collapsedLineNumbers.addAll(startToEndMap.keys);
    versionId++;
  }

  /// Expand all container-start lines, except parsed nested JSON containers.
  void expandAll() {
    collapsedLineNumbers.clear();
    collapsedLineNumbers.addAll(parsedContainerLineNumbers);
    versionId++;
  }

  /// Expand all collapsed containers that enclose [targetLineNumber].
  /// Returns `true` if any container was expanded.
  bool expandContainersOf(int targetLineNumber) {
    if (collapsedLineNumbers.isEmpty) return false;
    bool changed = false;
    // Check every collapsed container: if its range contains the target, expand it.
    final toRemove = <int>[];
    for (final startLine in collapsedLineNumbers) {
      final endLine = startToEndMap[startLine];
      if (endLine == null) continue;
      if (startLine < targetLineNumber && targetLineNumber <= endLine) {
        toRemove.add(startLine);
        changed = true;
      }
    }
    if (changed) {
      collapsedLineNumbers.removeAll(toRemove);
      versionId++;
    }
    return changed;
  }

  // ---- helpers ----

  /// Search all lines for [query] (case-insensitive).
  List<ModelSearchMatch> search(String query) {
    if (query.isEmpty) return const [];
    final lowerQuery = query.toLowerCase();
    final results = <ModelSearchMatch>[];
    for (final line in lines) {
      final lowerContent = line.content.toLowerCase();
      int start = 0;
      while (true) {
        final index = lowerContent.indexOf(lowerQuery, start);
        if (index == -1) break;
        results.add(
          ModelSearchMatch(
            lineNumber: line.lineNumber,
            startColumn: index,
            endColumn: index + query.length,
          ),
        );
        start = index + 1;
      }
    }
    return results;
  }

  static Map<int, int> _buildStartToEndMap(List<JsonLine> lines) {
    final map = <int, int>{};
    final stack = <int>[];
    for (final line in lines) {
      switch (line.lineType) {
        case JsonLineType.objectStart:
        case JsonLineType.arrayStart:
          stack.add(line.lineNumber);
          break;
        case JsonLineType.objectEnd:
        case JsonLineType.arrayEnd:
          if (stack.isNotEmpty) {
            map[stack.removeLast()] = line.lineNumber;
          }
          break;
        default:
          break;
      }
    }
    return map;
  }
}
