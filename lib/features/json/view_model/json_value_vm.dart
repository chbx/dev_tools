import 'dart:collection';

import '../../../common/collections.dart';
import '../core/json_value.dart';

sealed class JsonValueVM {
  static JsonValueVM from(JsonValue value) {
    switch (value) {
      case JsonNull():
        return JsonNullVM();
      case JsonBool():
        return JsonBoolVM(value.value);
      case JsonString():
        return _convertJsonString(value);
      case JsonNumber():
        return _convertJsonNumber(value);
      case JsonArray():
        final newElements = value.elements.map((e) => from(e)).toList();
        return JsonArrayVM(elements: newElements);
      case NormalJsonObject():
        return _convertNormalObject(value);
      case ExtendedJsonObject():
        return _convertExtendedObject(value);
    }
  }

  static JsonStringVM _convertJsonString(JsonString value) {
    bool allAscii = true;
    for (int i = 0; i < value.rawText.length; i++) {
      if (value.rawText.codeUnitAt(i) > 127) {
        allAscii = false;
        break;
      }
    }
    return JsonStringVM(
      rawText: value.rawText,
      allAscii: allAscii,
      value: value.value,
    );
  }

  static JsonNumberVM _convertJsonNumber(JsonNumber value) {
    return JsonNumberVM(rawText: value.rawText, value: value.value);
  }

  static JsonObjectVM _convertNormalObject(NormalJsonObject value) {
    final newMap = LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM>();
    value.entryMap.forEach((entryKey, entryValue) {
      final newKey = JsonObjectKeyStringVM(_convertJsonString(entryKey.value));
      newMap[newKey] = from(entryValue);
    });
    return NormalJsonObjectVM(entryMap: newMap);
  }

  static JsonObjectVM _convertExtendedObject(ExtendedJsonObject value) {
    final newMap = LinkedHashMap<JsonObjectKeyVM, JsonValueVM>();
    value.entryMap.forEach((entryKey, entryValue) {
      final newKey = switch (entryKey) {
        JsonObjectKeyString() => JsonObjectKeyStringVM(
          _convertJsonString(entryKey.value),
        ),
        JsonObjectKeyNumber() => JsonObjectKeyNumberVM(
          _convertJsonNumber(entryKey.value),
        ),
        JsonObjectKeyBool() => JsonObjectKeyBoolVM(
          JsonBoolVM(entryKey.value.value),
        ),
        JsonObjectKeyNull() => JsonObjectKeyNullVM(),
        JsonObjectKeyObject() => JsonObjectKeyObjectVM(
          _convertObject(entryKey.value),
        ),
      };
      newMap[newKey] = from(entryValue);
    });
    return ExtendedJsonObjectVM(entryMap: newMap);
  }

  static JsonObjectVM _convertObject(JsonObject value) {
    switch (value) {
      case NormalJsonObject():
        return _convertNormalObject(value);
      case ExtendedJsonObject():
        return _convertExtendedObject(value);
    }
  }

  // TODO duplicate code @see JsonValue
  static String toJsonString(JsonValueVM jsonValue) {
    final buffer = StringBuffer();
    _toJsonString(jsonValue, buffer);
    return buffer.toString();
  }

  static void _toJsonString(JsonValueVM jsonValue, StringBuffer buffer) {
    switch (jsonValue) {
      case JsonNullVM():
        buffer.write('null');
        break;
      case JsonBoolVM():
        buffer.write(jsonValue.value ? 'true' : 'false');
        break;
      case JsonStringVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonNumberVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonArrayVM():
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
      case NormalJsonObjectVM():
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
      case ExtendedJsonObjectVM():
        buffer.write('{');
        final iterator = jsonValue.entryMap.entries.iterator;
        if (iterator.moveNext()) {
          final first = iterator.current;
          _toStringKey(first.key, buffer);
          buffer.write(':');
          _toJsonString(first.value, buffer);
          while (iterator.moveNext()) {
            final entry = iterator.current;
            buffer.write(',');
            _toStringKey(entry.key, buffer);
            buffer.write(':');
            _toJsonString(entry.value, buffer);
          }
        }
        buffer.write('}');
        break;
    }
  }

  static void _toStringKey(JsonObjectKeyVM entryKey, StringBuffer buffer) {
    switch (entryKey) {
      case JsonObjectKeyNumberVM():
        _toJsonString(entryKey.value, buffer);
        break;
      case JsonObjectKeyBoolVM():
        _toJsonString(entryKey.value, buffer);
        break;
      case JsonObjectKeyNullVM():
        buffer.write('null');
        break;
      case JsonObjectKeyObjectVM():
        _toJsonString(entryKey.value, buffer);
        break;
      case JsonObjectKeyStringVM():
        _toJsonString(entryKey.value, buffer);
        break;
    }
  }
}

class JsonNullVM implements JsonValueVM {
  static const JsonNullVM _instance = JsonNullVM._internal();

  factory JsonNullVM() {
    return _instance;
  }

  const JsonNullVM._internal();

  String get rawText => "null";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonNullVM && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'JsonNullVM{}';
  }
}

class JsonBoolVM implements JsonValueVM {
  static const JsonBoolVM _true = JsonBoolVM._internal(true);
  static const JsonBoolVM _false = JsonBoolVM._internal(false);

  factory JsonBoolVM(bool value) {
    return value ? _true : _false;
  }

  final bool value;

  const JsonBoolVM._internal(this.value);

  String get rawText => value ? "true" : "false";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsonBoolVM && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonBoolVM{value: $value}';
  }
}

class JsonStringVM implements JsonValueVM {
  final String rawText;
  final bool allAscii;
  final String? value;
  JsonValueVM? parsed;

  JsonStringVM({required this.rawText, required this.allAscii, this.value});

  String getStringValue() {
    return value ?? rawText.substring(1, rawText.length - 1);
  }

  @override
  bool operator ==(Object other) {
    return other is JsonStringVM && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;

  @override
  String toString() {
    return 'JsonStringVM{rawText: $rawText, allAscii: $allAscii}';
  }
}

class JsonNumberVM implements JsonValueVM {
  final String rawText;
  final JsonNumberValue value;

  JsonNumberVM({required this.rawText, required this.value});

  @override
  bool operator ==(Object other) {
    return other is JsonNumberVM && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;

  @override
  String toString() {
    return 'JsonNumberVM{rawText: $rawText, value: $value}';
  }
}

class JsonArrayVM implements JsonValueVM {
  final List<JsonValueVM> elements;

  JsonArrayVM({required this.elements});

  @override
  bool operator ==(Object other) {
    return other is JsonArrayVM && listEquals(other.elements, elements);
  }

  @override
  int get hashCode => Object.hashAll(elements);

  @override
  String toString() {
    return 'JsonArrayVM{elements: $elements}';
  }
}

sealed class JsonObjectVM implements JsonValueVM {}

class NormalJsonObjectVM implements JsonObjectVM, JsonValueVM {
  final LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> entryMap;

  // fastjson {"$ref": ""}
  JsonValueVM? ref;

  NormalJsonObjectVM({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is NormalJsonObjectVM && mapEquals(other.entryMap, entryMap);
  }

  @override
  int get hashCode => mapHashCode(entryMap);

  @override
  String toString() {
    return 'NormalJsonObjectVM{entryMap: $entryMap}';
  }
}

class ExtendedJsonObjectVM implements JsonObjectVM, JsonValueVM {
  final LinkedHashMap<JsonObjectKeyVM, JsonValueVM> entryMap;

  ExtendedJsonObjectVM({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is ExtendedJsonObjectVM && other.entryMap == entryMap;
  }

  @override
  int get hashCode => mapHashCode(entryMap);

  @override
  String toString() {
    return 'ExtendedJsonObjectVM{entryMap: $entryMap}';
  }
}

sealed class JsonObjectKeyVM {}

class JsonObjectKeyStringVM implements JsonObjectKeyVM {
  final JsonStringVM value;

  JsonObjectKeyStringVM(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyStringVM && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyStringVM{value: $value}';
  }
}

class JsonObjectKeyNumberVM implements JsonObjectKeyVM {
  final JsonNumberVM value;

  JsonObjectKeyNumberVM(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyNumberVM && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyNumberVM{value: $value}';
  }
}

class JsonObjectKeyBoolVM implements JsonObjectKeyVM {
  final JsonBoolVM value;

  JsonObjectKeyBoolVM(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyBoolVM && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyBoolVM{value: ${value.value}}';
  }
}

class JsonObjectKeyNullVM implements JsonObjectKeyVM {
  static const JsonObjectKeyNullVM _instance = JsonObjectKeyNullVM._internal();

  factory JsonObjectKeyNullVM() {
    return _instance;
  }

  const JsonObjectKeyNullVM._internal();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonObjectKeyNullVM && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyNullVM{}';
  }
}

class JsonObjectKeyObjectVM implements JsonObjectKeyVM {
  final JsonObjectVM value;

  JsonObjectKeyObjectVM(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyObjectVM && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyObjectVM{value: $value}';
  }
}
