import 'dart:collection';

import '../../../common/collections.dart';
import '../core/json_value.dart' as core;

sealed class JsonValue {}

class JsonNull implements JsonValue {
  static const JsonNull _instance = JsonNull._internal();

  factory JsonNull() {
    return _instance;
  }

  const JsonNull._internal();

  String get rawText => "null";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonNull && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

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

  final bool value;

  const JsonBool._internal(this.value);

  String get rawText => value ? "true" : "false";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JsonBool && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonBool{value: $value}';
  }
}

class JsonString implements JsonValue {
  final String rawText;
  final bool allAscii;
  final String? value;
  JsonValue? parsed;

  JsonString({required this.rawText, required this.allAscii, this.value});

  String getStringValue() {
    return value ?? rawText.substring(1, rawText.length - 1);
  }

  @override
  bool operator ==(Object other) {
    return other is JsonString && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;

  @override
  String toString() {
    return 'JsonString{rawText: $rawText, allAscii: $allAscii}';
  }
}

class JsonNumber implements JsonValue {
  final String rawText;
  final core.JsonNumberValue value;
  String? dateHint;

  JsonNumber({required this.rawText, required this.value});

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
  final List<JsonValue> elements;

  JsonArray({required this.elements});

  @override
  bool operator ==(Object other) {
    return other is JsonArray && listEquals(other.elements, elements);
  }

  @override
  int get hashCode => Object.hashAll(elements);

  @override
  String toString() {
    return 'JsonArray{elements: $elements}';
  }
}

sealed class JsonObject implements JsonValue {}

class NormalJsonObject implements JsonObject, JsonValue {
  final LinkedHashMap<JsonObjectKeyString, JsonValue> entryMap;

  // fastjson {"$ref": ""}
  JsonValue? ref;

  String? shortString;

  NormalJsonObject({required this.entryMap});

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

class ExtendedJsonObject implements JsonObject, JsonValue {
  final LinkedHashMap<JsonObjectKey, JsonValue> entryMap;

  ExtendedJsonObject({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is ExtendedJsonObject && other.entryMap == entryMap;
  }

  @override
  int get hashCode => mapHashCode(entryMap);

  @override
  String toString() {
    return 'ExtendedJsonObject{entryMap: $entryMap}';
  }
}

sealed class JsonObjectKey {}

class JsonObjectKeyString implements JsonObjectKey {
  final JsonString value;

  JsonObjectKeyString(this.value);

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

class JsonObjectKeyNumber implements JsonObjectKey {
  final JsonNumber value;

  JsonObjectKeyNumber(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyNumber && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyNumber{value: $value}';
  }
}

class JsonObjectKeyBool implements JsonObjectKey {
  final JsonBool value;

  JsonObjectKeyBool(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyBool && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyBool{value: ${value.value}}';
  }
}

class JsonObjectKeyNull implements JsonObjectKey {
  static const JsonObjectKeyNull _instance = JsonObjectKeyNull._internal();

  factory JsonObjectKeyNull() {
    return _instance;
  }

  const JsonObjectKeyNull._internal();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonObjectKeyNull && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyNull{}';
  }
}

class JsonObjectKeyObject implements JsonObjectKey {
  final JsonObject value;

  JsonObjectKeyObject(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyObject && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'JsonObjectKeyObject{value: $value}';
  }
}
