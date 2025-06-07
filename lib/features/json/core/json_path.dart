import 'dart:collection';

import '../view_model/json_value_vm.dart';
import 'json_path_parser.dart';
import 'json_path_segment.dart';

class JsonPath {
  final String path;
  final List<JsonPathSegment> segments;

  JsonPath({required this.path, required this.segments});

  static JsonPath? parse(String path, {bool fastJsonMode = false}) {
    return JsonPathParser.parse(path, fastJsonMode: fastJsonMode);
  }

  // TODO 不使用 jsonValueVM
  JsonValueVM? resolve(JsonValueVM jsonValue) {
    JsonValueVM parsed = jsonValue;
    for (final segment in segments) {
      switch (segment) {
        case JsonPathSegmentSingleIndex():
          if (parsed is JsonArrayVM) {
            if (segment.index < parsed.elements.length) {
              parsed = parsed.elements[segment.index];
            } else {
              return null;
            }
          } else {
            return null;
          }
          break;
        case JsonPathSegmentSingleName():
          if (parsed is NormalJsonObjectVM) {
            final currentValue = getEntryMapValue(
              parsed.entryMap,
              segment.name,
            );
            if (currentValue != null) {
              parsed = currentValue;
            } else {
              return null;
            }
          } else {
            return null;
          }
          break;
      }
    }
    return parsed;
  }
}

class CashedParser {
  final _cache = HashMap<String, JsonPath>();

  JsonPath? parse(String text) {
    final cached = _cache[text];
    if (cached != null) {
      return cached;
    }
    final jsonPath = JsonPath.parse(text, fastJsonMode: true);
    // TODO cache failed jsonPath
    if (jsonPath != null) {
      _cache[text] = jsonPath;
    }
    return jsonPath;
  }
}

// TODO duplicate code
JsonValueVM? getEntryMapValue(
  Map<JsonObjectKeyStringVM, JsonValueVM> map,
  String keyValue,
) {
  return map[JsonObjectKeyStringVM(
    // TODO allAscii
    JsonStringVM(rawText: '"$keyValue"', allAscii: false),
  )];
}
