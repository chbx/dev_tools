import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;

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

  void processTree(JsonValueVM jsonValue, {JsonObjectKeyVM? jsonKey}) {
    try {
      switch (jsonValue) {
        case JsonStringVM():
          if (options.parseNestedJsonString) {
            _parseNestedString(jsonValue);
          }
          break;
        case JsonNumberVM():
          if (options.showDateHint) {
            _processDateHint(jsonValue, jsonKey);
          }
          break;
        case NormalJsonObjectVM():
          _processNormalObject(jsonValue);
          for (final entry in jsonValue.entryMap.entries) {
            processTree(entry.value,  jsonKey: entry.key);
          }
          break;
        case JsonArrayVM():
          for (final element in jsonValue.elements) {
            processTree(element);
          }
          break;
        case ExtendedJsonObjectVM():
          for (final entry in jsonValue.entryMap.entries) {
            processTree(entry.value, jsonKey: entry.key);
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
    if (options.showMoneyHint) {
      _processNormalObjectShorForMoney(jsonValue);
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

  void _processNormalObjectShorForMoney(NormalJsonObjectVM jsonValue) {
    final entryMap = jsonValue.entryMap;
    if (entryMap.length == 2) {
      // {"cent": 0,"currency": "CNY"}
      final cent = getEntryMapValue(entryMap, 'cent');
      final currency = getEntryMapValue(entryMap, 'currency');
      if (cent is JsonNumberVM && currency is JsonStringVM) {
        jsonValue.shortString = _buildMoneyShortString(cent, currency);
      }
    } else if (entryMap.length == 6) {
      // {"amount":50.00,"cent":5000,"centFactor":100,
      // "currency":"CNY","currencyCode":"CNY","displayUnit":"元"}
      final fields = [
        'amount',
        'cent',
        'centFactor',
        'currency',
        'currencyCode',
        'displayUnit',
      ];
      if (_containsAllField(entryMap, fields)) {
        final cent = getEntryMapValue(entryMap, 'cent');
        final currency = getEntryMapValue(entryMap, 'currency');
        if (cent is JsonNumberVM && currency is JsonStringVM) {
          jsonValue.shortString = _buildMoneyShortString(cent, currency);
        }
      }
    }
  }

  String? _buildMoneyShortString(JsonNumberVM cent, JsonStringVM currency) {
    final centValue = cent.value;
    if (centValue is JsonNumberValueInt) {
      final formatter = intl.NumberFormat('#,###0.##');
      final formatted = formatter.format(centValue.intValue / 100);
      final currencyStr = currency.getStringValue();
      return '$currencyStr $formatted';
    } else {
      return null;
    }
  }

  // {"date": 0, "time": 0}
  void _processDateHint(JsonNumberVM jsonValue, JsonObjectKeyVM? jsonKey) {
    if (jsonKey == null) {
      return;
    }
    final jsonNum = jsonValue.value;
    if (jsonKey is JsonObjectKeyStringVM && jsonNum is JsonNumberValueInt) {
      final jsonKeyStr = jsonKey.value.getStringValue().toLowerCase();
      if (jsonKeyStr.contains('gmt') ||
          jsonKeyStr.contains('date') ||
          jsonKeyStr.contains('time')) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(jsonNum.intValue);

        String dateTimeStr;
        if (jsonNum.intValue % 1000 == 0) {
          final dateFormatStr = 'yyyy-MM-dd HH:mm:ss';
          dateTimeStr = intl.DateFormat(dateFormatStr).format(dateTime);
          if (dateTimeStr.endsWith('00:00:00')) {
            dateTimeStr = dateTimeStr.substring(0, 10);
          }
        } else {
          final dateFormatStr = 'yyyy-MM-dd HH:mm:ss.SSS';
          dateTimeStr = intl.DateFormat(dateFormatStr).format(dateTime);
        }

        final offset = dateTime.timeZoneOffset;
        final utcHourOffset =
            (offset.isNegative ? '-' : '+') +
            offset.inHours.abs().toString().padLeft(2, '0');
        final utcMinuteOffset = (offset.inMinutes - offset.inHours * 60)
            .toString()
            .padLeft(2, '0');
        final dateTimeWithOffset =
            '$dateTimeStr$utcHourOffset:$utcMinuteOffset';
        jsonValue.dateHint = dateTimeWithOffset;
      }
    }
  }
}

bool _containsAllField(
  Map<JsonObjectKeyStringVM, JsonValueVM> map,
  List<String> fieldNames,
) {
  for (final fieldName in fieldNames) {
    final value = getEntryMapValue(map, fieldName);
    if (value == null) {
      return false;
    }
  }
  return true;
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
