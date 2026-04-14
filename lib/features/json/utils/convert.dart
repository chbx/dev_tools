import 'dart:collection';

import '../core/json_value.dart' as core;
import '../model/json_value.dart';

JsonValue convertJsonValue(core.JsonValue value) {
  switch (value) {
    case core.JsonNull():
      return JsonNull();
    case core.JsonBool():
      return JsonBool(value.value);
    case core.JsonString():
      return _convertJsonString(value);
    case core.JsonNumber():
      return _convertJsonNumber(value);
    case core.JsonArray():
      final newElements =
          value.elements.map((e) => convertJsonValue(e)).toList();
      return JsonArray(elements: newElements);
    case core.NormalJsonObject():
      return _convertNormalObject(value);
    case core.ExtendedJsonObject():
      return _convertExtendedObject(value);
  }
}

JsonString _convertJsonString(core.JsonString value) {
  bool allAscii = true;
  for (int i = 0; i < value.rawText.length; i++) {
    if (value.rawText.codeUnitAt(i) > 127) {
      allAscii = false;
      break;
    }
  }
  return JsonString(
    rawText: value.rawText,
    allAscii: allAscii,
    value: value.value,
  );
}

JsonNumber _convertJsonNumber(core.JsonNumber value) {
  return JsonNumber(rawText: value.rawText, value: value.value);
}

JsonObject _convertNormalObject(core.NormalJsonObject value) {
  final newMap = LinkedHashMap<JsonObjectKeyString, JsonValue>();
  value.entryMap.forEach((entryKey, entryValue) {
    final newKey = JsonObjectKeyString(_convertJsonString(entryKey.value));
    newMap[newKey] = convertJsonValue(entryValue);
  });
  return NormalJsonObject(entryMap: newMap);
}

JsonObject _convertExtendedObject(core.ExtendedJsonObject value) {
  final newMap = LinkedHashMap<JsonObjectKey, JsonValue>();
  value.entryMap.forEach((entryKey, entryValue) {
    final newKey = switch (entryKey) {
      core.JsonObjectKeyString() => JsonObjectKeyString(
        _convertJsonString(entryKey.value),
      ),
      core.JsonObjectKeyNumber() => JsonObjectKeyNumber(
        _convertJsonNumber(entryKey.value),
      ),
      core.JsonObjectKeyBool() => JsonObjectKeyBool(
        JsonBool(entryKey.value.value),
      ),
      core.JsonObjectKeyNull() => JsonObjectKeyNull(),
      core.JsonObjectKeyObject() => JsonObjectKeyObject(
        _convertObject(entryKey.value),
      ),
    };
    newMap[newKey] = convertJsonValue(entryValue);
  });
  return ExtendedJsonObject(entryMap: newMap);
}

JsonObject _convertObject(core.JsonObject value) {
  switch (value) {
    case core.NormalJsonObject():
      return _convertNormalObject(value);
    case core.ExtendedJsonObject():
      return _convertExtendedObject(value);
  }
}
