import '../model/json_value.dart';

String jsonValueToString(JsonValue jsonValue) {
  final buffer = StringBuffer();
  _toJsonString(jsonValue, buffer);
  return buffer.toString();
}

void _toJsonString(JsonValue jsonValue, StringBuffer buffer) {
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
    case ExtendedJsonObject():
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

void _toStringKey(JsonObjectKey entryKey, StringBuffer buffer) {
  switch (entryKey) {
    case JsonObjectKeyNumber():
      _toJsonString(entryKey.value, buffer);
      break;
    case JsonObjectKeyBool():
      _toJsonString(entryKey.value, buffer);
      break;
    case JsonObjectKeyNull():
      buffer.write('null');
      break;
    case JsonObjectKeyObject():
      _toJsonString(entryKey.value, buffer);
      break;
    case JsonObjectKeyString():
      _toJsonString(entryKey.value, buffer);
      break;
  }
}
