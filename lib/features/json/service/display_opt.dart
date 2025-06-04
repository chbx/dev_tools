import 'package:flutter/foundation.dart';

import '../core/json_parser.dart';
import '../core/json_parser_options.dart';
import '../core/json_value.dart';
import '../model/viewer_options.dart';
import '../view_model/json_value_vm.dart';

class JsonValueDisplayOptimizer {
  final JsonViewerOptions options;

  JsonValueDisplayOptimizer({required this.options});

  void processTree(JsonValueVM jsonValue) {
    return _doProcessTree(jsonValue);
  }

  bool _isNestedStart(String firstChar) => firstChar == '[' || firstChar == '{';

  void _doProcessTree(JsonValueVM jsonValue) {
    switch (jsonValue) {
      case JsonStringVM():
        if (options.parseNestedJsonString) {
          _parseNestedString(jsonValue);
        }
        break;
      case JsonNumberVM():
        break;
      case NormalJsonObjectVM():
        for (final entry in jsonValue.entryMap.entries) {
          _doProcessTree(entry.value);
        }
        break;
      case JsonArrayVM():
        for (final element in jsonValue.elements) {
          _doProcessTree(element);
        }
        break;
      case ExtendedJsonObjectVM():
        for (final entry in jsonValue.entryMap.entries) {
          _doProcessTree(entry.value);
        }
        break;
      default:
        break;
    }
  }

  void _parseNestedString(JsonStringVM jsonValue) {
    jsonValue.parsed = _parseNestedJsonString(
      rawText: jsonValue.rawText,
      text: jsonValue.value,
    );
  }

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

    try {
      final parsedValue = JsonParser.parse(jsonString, options: parseOptions);

      final structuredValueString = JsonValueVM.from(parsedValue);
      processTree(structuredValueString);

      return structuredValueString;
    } catch (e, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stackTrace),
      );
      return null;
    }
  }
}
