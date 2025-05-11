import 'package:dev_tools/features/json/core/json_value.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher isJsonValue(JsonValue value) {
  return allOf(_isJsonValueFieldMatch(value), equals(value));
}

Matcher _isJsonValueFieldMatch(JsonValue value) {
  return switch (value) {
    JsonString() => _isJsonString(value),
    JsonNumber() => _isJsonNumber(value),
    JsonBool() => same(JsonBool(value.value)),
    JsonNull() => same(JsonNull()),
    JsonArray() => _isJsonArray(value),
    NormalJsonObject() => _isJsonObject(value),
  };
}

Matcher _isJsonString(JsonString value) {
  return isA<JsonString>()
      .having((v) => v.rawText, 'rawText', value.rawText)
      .having((v) => v.value, 'value', value.value);
}

Matcher _isJsonNumber(JsonNumber value) {
  final numValue = value.value;
  return isA<JsonNumber>()
      .having((v) => v.rawText, 'rawText', value.rawText)
      .having((v) => v.value, 'value', switch (numValue) {
        JsonNumberValueInt() => numValue,
        JsonNumberValueFloat() => isA<JsonNumberValueFloat>().having(
          (v) => v.floatValue,
          'floatValue',
          moreOrLessEquals(numValue.floatValue, epsilon: 1e-10),
        ),
      });
}

Matcher _isJsonArray(JsonArray value) {
  final matchers =
      value.elements.map((e) => _isJsonValueFieldMatch(e)).toList();

  return isA<JsonArray>().having((v) => v.elements, 'elements', matchers);
}

Matcher _isJsonObject(NormalJsonObject value) {
  final matchers =
      value.entryMap.entries
          .map(
            (expectedEntry) => isA<MapEntry<JsonObjectKeyString, JsonValue>>()
                .having(
                  (e) => e.key,
                  'entry.key',
                  _isJsonObjectKey(expectedEntry.key),
                )
                .having(
                  (e) => e.value,
                  'entry.value',
                  _isJsonValueFieldMatch(expectedEntry.value),
                ),
          )
          .toList();

  return isA<NormalJsonObject>().having(
    (v) => v.entryMap.entries,
    'entryMap.entries',
    matchers,
  );
}

Matcher _isJsonObjectKey(JsonObjectKey objectKey) {
  return switch (objectKey) {
    JsonObjectKeyString() => isA<JsonObjectKeyString>().having(
      (v) => v.value,
      "value",
      _isJsonValueFieldMatch(objectKey.value),
    ),
  };
}
