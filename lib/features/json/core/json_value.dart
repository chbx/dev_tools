import 'dart:collection';

import '../../../common/collections.dart';

sealed class JsonValue {
  const JsonValue();

  static String toJsonString(JsonValue jsonValue) {
    final buffer = StringBuffer();
    _toJsonString(jsonValue, buffer);
    return buffer.toString();
  }

  static void _toJsonString(JsonValue jsonValue, StringBuffer buffer) {
    switch (jsonValue) {
      case JsonNull():
        buffer.write('null');
        break;
      case JsonBool():
        buffer.write(jsonValue.value ? 'true' : 'false');
        break;
      case JsonString():
        buffer.write(jsonValue.rawText);
        break;
      case JsonNumber():
        buffer.write(jsonValue.rawText);
        break;
      case JsonArray():
        buffer.write('[');
        final iterator = jsonValue.elements.iterator;
        if (iterator.moveNext()) {
          _toJsonString(iterator.current, buffer);
          while (iterator.moveNext()) {
            buffer.write(',');
            _toJsonString(iterator.current, buffer);
          }
        }
        buffer.write(']');
        break;
      case NormalJsonObject():
        buffer.write('{');
        final iterator = jsonValue.entryMap.entries.iterator;
        if (iterator.moveNext()) {
          final first = iterator.current;
          buffer.write(first.key.value.rawText);
          buffer.write(':');
          _toJsonString(first.value, buffer);
          while (iterator.moveNext()) {
            final entry = iterator.current;
            buffer.write(',');
            buffer.write(entry.key.value.rawText);
            buffer.write(':');
            _toJsonString(entry.value, buffer);
          }
        }
        buffer.write('}');
        break;
    }
  }
}

class JsonNull implements JsonValue {
  static const JsonNull _instance = JsonNull._internal();

  factory JsonNull() {
    return _instance;
  }

  const JsonNull._internal();

  String get rawText => "null";

  @override
  String toString() {
    return 'JsonNull{}';
  }
}

class JsonBool implements JsonValue {
  static const JsonBool _true = JsonBool._internal(true);
  static const JsonBool _false = JsonBool._internal(false);

  factory JsonBool(bool value) {
    return value ? _true : _false;
  }

  const JsonBool._internal(this.value);

  final bool value;

  String get rawText => value ? "true" : "false";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonBool && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonBool{value: $value}';
  }
}

class JsonString implements JsonValue {
  const JsonString({required this.rawText, required this.value});

  final String rawText;
  final String? value;

  @override
  bool operator ==(Object other) {
    return other is JsonString && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;

  @override
  String toString() {
    return 'JsonString{rawText: $rawText, value: $value}';
  }
}

sealed class JsonNumberValue {
  const JsonNumberValue();
}

class JsonNumberValueInt extends JsonNumberValue {
  const JsonNumberValueInt(this.intValue);

  final int intValue;

  @override
  bool operator ==(Object other) {
    return other is JsonNumberValueInt && other.intValue == intValue;
  }

  @override
  int get hashCode => intValue.hashCode;

  @override
  String toString() {
    return 'JsonNumberValueInt{intValue: $intValue}';
  }
}

class JsonNumberValueFloat extends JsonNumberValue {
  const JsonNumberValueFloat(this.floatValue);

  final double floatValue;

  @override
  String toString() {
    return 'JsonNumberValueFloat{floatValue: $floatValue}';
  }
}

class JsonNumber implements JsonValue {
  const JsonNumber({required this.rawText, required this.value});

  final String rawText;
  final JsonNumberValue value;

  @override
  bool operator ==(Object other) {
    return other is JsonNumber && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;

  @override
  String toString() {
    return 'JsonNumber{rawText: $rawText, value: $value}';
  }
}

class JsonArray implements JsonValue {
  const JsonArray({required this.elements});

  final List<JsonValue> elements;

  @override
  bool operator ==(Object other) {
    return other is JsonArray && listEquals(other.elements, elements);
  }

  // TODO cache hashCode
  @override
  int get hashCode => Object.hashAll(elements);

  @override
  String toString() {
    return 'JsonArray{elements: $elements}';
  }
}

sealed class JsonObject implements JsonValue {}

class NormalJsonObject implements JsonObject, JsonValue {
  const NormalJsonObject({required this.entryMap});

  final LinkedHashMap<JsonObjectKeyString, JsonValue> entryMap;

  @override
  bool operator ==(Object other) {
    return other is NormalJsonObject && mapEquals(other.entryMap, entryMap);
  }

  @override
  int get hashCode => mapHashCode(entryMap);

  @override
  String toString() {
    return 'NormalJsonObject{entryMap: $entryMap}';
  }
}

sealed class JsonObjectKey {
  const JsonObjectKey();
}

class JsonObjectKeyString implements JsonObjectKey {
  const JsonObjectKeyString(this.value);

  final JsonString value;

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyString && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyString{value: $value}';
  }
}
