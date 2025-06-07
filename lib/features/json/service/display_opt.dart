import 'package:flutter/foundation.dart';

import '../core/json_parser.dart';
import '../core/json_parser_options.dart';
import '../core/json_path.dart';
import '../core/json_value.dart';
import '../model/viewer_options.dart';
import '../view_model/json_value_vm.dart';

void optimizeDisplayInfo(JsonValueVM jsonValue, JsonViewerOptions options) {
  _JsonValueDisplayOptimizer(
    context: jsonValue,
    options: options,
  ).processTree(jsonValue);
}

class _JsonValueDisplayOptimizer {
  _JsonValueDisplayOptimizer({required this.context, required this.options});

  final JsonViewerOptions options;
  final JsonValueVM context;
  final CashedParser _cashedParser = CashedParser();

  void processTree(JsonValueVM jsonValue) {
    try {
      switch (jsonValue) {
        case JsonStringVM():
          if (options.parseNestedJsonString) {
            _parseNestedString(jsonValue);
          }
          break;
        case JsonNumberVM():
          break;
        case NormalJsonObjectVM():
          _processNormalObject(jsonValue);
          for (final entry in jsonValue.entryMap.entries) {
            processTree(entry.value);
          }
          break;
        case JsonArrayVM():
          for (final element in jsonValue.elements) {
            processTree(element);
          }
          break;
        case ExtendedJsonObjectVM():
          for (final entry in jsonValue.entryMap.entries) {
            processTree(entry.value);
          }
          break;
        default:
          break;
      }
    } catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
    }
  }

  void _parseNestedString(JsonStringVM jsonValue) {
    jsonValue.parsed = _parseNestedJsonString(
      rawText: jsonValue.rawText,
      text: jsonValue.value,
    );
  }

  bool _isNestedStart(String firstChar) => firstChar == '[' || firstChar == '{';

  JsonValueVM? _parseNestedJsonString({
    required String rawText,
    required String? text,
  }) {
    const minWidth = 4;
    const parseOptions = JsonParseOptions.loose(
      backSlashEscapeType: BackSlashEscapeType.onlyBackSlashAndDoubleQuote,
    );

    String? jsonString;
    while (true) {
      if (text != null) {
        if (text.length > minWidth) {
          final firstChar = text[0];
          if (_isNestedStart(firstChar)) {
            jsonString = text;
          } else if (firstChar == '"') {
            try {
              final parsedValue = JsonParser.parse(text, options: parseOptions);
              // first char is '"', if parsing is successful,
              // the resulting value should be a JSON string
              if (parsedValue is JsonString) {
                rawText = parsedValue.rawText;
                text = parsedValue.value;
                continue;
              } else {
                return null;
              }
            } catch (e) {}
          }
        }
      } else {
        if (rawText.length > minWidth + 2) {
          final firstChar = rawText[1];
          if (_isNestedStart(firstChar)) {
            jsonString = rawText.substring(1, rawText.length - 1);
          }
        }
      }
      break;
    }

    if (jsonString == null) {
      return null;
    }

    final parsedValue = JsonParser.parse(jsonString, options: parseOptions);
    final parsedNestedStringVM = JsonValueVM.from(parsedValue);
    optimizeDisplayInfo(parsedNestedStringVM, options);
    return parsedNestedStringVM;
  }

  void _processNormalObject(NormalJsonObjectVM jsonValue) {
    if (options.parseFastJsonRef) {
      _processFastJsonRef(jsonValue);
    }
  }

  // [{"name":"张三"},{"$ref":"$[0]"}]
  // [{"name":"zs","rel":{"name":"lisi","rel":{"$ref":".."}}},{"$ref":"$[0].rel"}]
  void _processFastJsonRef(NormalJsonObjectVM jsonValue) {
    final entryMap = jsonValue.entryMap;
    if (entryMap.length != 1) {
      return;
    }
    final ref = getEntryMapValue(entryMap, r'$ref');
    if (ref is! JsonStringVM) {
      return;
    }
    final value = ref.getStringValue();
    final jsonPath = _cashedParser.parse(value);
    if (jsonPath == null) {
      return;
    }
    jsonValue.ref = jsonPath.resolve(context);
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
