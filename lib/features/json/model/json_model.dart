import 'dart:collection';

import '../utils/line_builder.dart';
import 'json_line.dart';
import 'json_value.dart';

/// Encapsulates the flattened lines, structure map, and independent collapse
/// state for a single `$ref` expansion.
class RefExpandedCache {
  final List<JsonLine> lines;
  final Map<int, int> startToEndMap;
  final Set<int> collapsedLineNumbers;

  RefExpandedCache({
    required this.lines,
    required this.startToEndMap,
  }) : collapsedLineNumbers = {};

  bool toggleCollapse(int lineNumber) {
    if (!startToEndMap.containsKey(lineNumber)) return false;
    if (collapsedLineNumbers.contains(lineNumber)) {
      collapsedLineNumbers.remove(lineNumber);
    } else {
      collapsedLineNumbers.add(lineNumber);
    }
    return true;
  }
}

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

  /// Set of line numbers whose `$ref` has been expanded to show the
  /// dereferenced value instead of the original `{"$ref":"..."}` content.
  final Set<int> refExpandedLineNumbers;

  /// Caches the flattened lines, structure map, and independent collapse state
  /// for each ref-expanded container-start line.  Keyed by line number.
  final Map<int, RefExpandedCache> refExpandedLinesCache;

  int versionId;

  JsonModel._(
      {required this.rootValue,
      required this.lines,
      required this.startToEndMap,
      required this.parsedContainerLineNumbers,
      Set<int>? collapsedLineNumbers,
      this.versionId = 0 // ignore: unused_element_parameter
      })
      : collapsedLineNumbers = collapsedLineNumbers ?? {},
        refExpandedLineNumbers = {},
        refExpandedLinesCache = {};

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
      if (line.shortString != null) {
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

  /// Toggle the ref-expand state of a container-start line that has a
  /// fastjson `$ref`.  When expanded, the dereferenced value's lines replace
  /// the original `{"$ref":"..."}` children.
  /// Returns `true` if the state changed.
  bool toggleRefExpand(int lineNumber) {
    final line = lines.firstWhere(
      (l) => l.lineNumber == lineNumber,
      orElse: () => lines.first,
    );
    if (line.lineNumber != lineNumber) return false;
    if (line.refValue == null) return false;

    if (refExpandedLineNumbers.contains(lineNumber)) {
      refExpandedLineNumbers.remove(lineNumber);
    } else {
      refExpandedLineNumbers.add(lineNumber);
      // Build and cache the ref lines if not already cached.
      // Use the same indent level as the original object so the ref value
      // fully replaces the `{"$ref":"..."}` object.
      if (!refExpandedLinesCache.containsKey(lineNumber)) {
        final refLines = buildJsonLines(
          line.refValue!,
          baseIndent: line.indentLevel,
        );
        // Inject the original object's key prefix (e.g. `"keyRef": `) into
        // the first ref line so the key association is preserved.
        if (refLines.isNotEmpty) {
          final keyTokens = <JsonLineToken>[];
          for (final token in line.tokens) {
            if (token.type == JsonTokenType.bracket) break;
            keyTokens.add(token);
          }
          if (keyTokens.isNotEmpty) {
            final firstRefLine = refLines[0];
            final mergedTokens = [...keyTokens, ...firstRefLine.tokens];
            final mergedContent = mergedTokens.map((t) => t.text).join();
            refLines[0] = JsonLine(
              lineNumber: firstRefLine.lineNumber,
              content: mergedContent,
              indentLevel: firstRefLine.indentLevel,
              lineType: firstRefLine.lineType,
              tokens: mergedTokens,
              isBasicASCII: firstRefLine.isBasicASCII,
              childCount: firstRefLine.childCount,
              parsedFromRawText: firstRefLine.parsedFromRawText,
              refValue: line.refValue,
              shortString: firstRefLine.shortString,
            );
          }
        }
        refExpandedLinesCache[lineNumber] = RefExpandedCache(
          lines: refLines,
          startToEndMap: _buildStartToEndMap(refLines),
        );
      }
    }
    versionId++;
    return true;
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

  /// Toggle the collapse state of a container-start line **inside** a
  /// ref-expanded cache.  Uses the cache's independent collapse state so
  /// it does not interfere with the main model's collapse state.
  /// [refSourceLineNumber] identifies which ref cache to operate on.
  /// Returns `true` if the state changed.
  bool toggleRefCollapse(int refSourceLineNumber, int lineNumber) {
    final cache = refExpandedLinesCache[refSourceLineNumber];
    if (cache == null) return false;
    if (!cache.toggleCollapse(lineNumber)) return false;
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
