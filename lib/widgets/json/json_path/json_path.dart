import '../model.dart';
import 'json_path_parser.dart';
import 'json_path_segment.dart';

class JsonPath {
  final String path;
  final List<JsonPathSegment> segments;

  JsonPath({required this.path, required this.segments});

  static JsonPath? parse(String path, {bool fastJsonMode = false}) {
    return JsonPathParser.parse(path, fastJsonMode: fastJsonMode);
  }

  JsonValueVM? resolve(JsonValueVM jsonValue) {
    JsonValueVM parsed = jsonValue;
    for (var segment in segments) {
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
            var currentValue = getEntryMapValue(parsed.entryMap, segment.name);
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
