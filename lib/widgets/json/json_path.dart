import 'package:dev_tools/widgets/json/model.dart';

class JsonPath {
  final String path;
  final List<JsonPathSegment> segments;

  JsonPath._internal({required this.path, required this.segments});

  static JsonPath? compile(String path) {
    if (path.isEmpty || path[0] != r'$') {
      return null;
    }

    final segments = <JsonPathSegment>[];
    final buffer = StringBuffer();
    bool escape = false;

    for (int i = 1; i < path.length; i++) {
      final char = path[i];

      if (escape) {
        if (char == '[' || char == '.' || char == '\\') {
          buffer.write(char);
        } else {
          return null; // 不支持的转义字符
        }
        escape = false;
      } else if (char == '\\') {
        escape = true;
        if (buffer.isNotEmpty) {
          return null; // 转义符号前不能有未处理的字符
        }
      } else if (char == '.') {
        if (buffer.isNotEmpty) {
          segments.add(JsonPathSegmentName(buffer.toString()));
          buffer.clear();
        }
      } else if (char == '[') {
        if (buffer.isNotEmpty) {
          segments.add(JsonPathSegmentName(buffer.toString()));
          buffer.clear();
        }

        // 解析索引
        int endBracket = path.indexOf(']', i + 1);
        if (endBracket == -1) return null;

        final indexStr = path.substring(i + 1, endBracket);
        final index = int.tryParse(indexStr);
        if (index is int) {
          segments.add(JsonPathSegmentIndex(index));
          i = endBracket; // 移动到 ] 的位置
        } else {
          return null; // 非数字索引
        }
      } else {
        buffer.write(char);
      }
    }

    if (escape) return null; // 结尾是转义符号

    if (buffer.isNotEmpty) {
      segments.add(JsonPathSegmentName(buffer.toString()));
    }

    return JsonPath._internal(path: path, segments: segments);
  }

  JsonValueVM? resolve(JsonValueVM jsonValue) {
    JsonValueVM parsed = jsonValue;
    for (var segment in segments) {
      switch (segment) {
        case JsonPathSegmentIndex():
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
        case JsonPathSegmentName():
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

class JsonPathSegment {}

class JsonPathSegmentIndex extends JsonPathSegment {
  final int index;

  JsonPathSegmentIndex(this.index);
}

class JsonPathSegmentName extends JsonPathSegment {
  final String name;

  JsonPathSegmentName(this.name);
}
