import 'dart:collection';

import 'parser/parser.dart';
import 'parser/tokenizer.dart' show JsonNumberValue;

sealed class JsonValueVM {}

class JsonNullVM implements JsonValueVM {
  static const JsonNullVM _instance = JsonNullVM._internal();

  factory JsonNullVM() {
    return _instance;
  }

  const JsonNullVM._internal();

  String get rawText => "null";
}

class JsonStringVM implements JsonValueVM {
  String rawText;

  JsonValueVM? parsed;

  JsonStringVM({required this.rawText, this.parsed});

  @override
  bool operator ==(Object other) {
    return other is JsonStringVM && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;
}

class JsonBoolVM implements JsonValueVM {
  final bool _value;
  static const JsonBoolVM _true = JsonBoolVM._internal(true);
  static const JsonBoolVM _false = JsonBoolVM._internal(false);

  factory JsonBoolVM(bool value) {
    return value ? _true : _false;
  }

  const JsonBoolVM._internal(this._value);

  String get rawText => _value ? "true" : "false";

  bool get value => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonBoolVM && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
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
}

class JsonArrayVM implements JsonValueVM {
  final List<JsonValueVM> elements;

  JsonArrayVM({required this.elements});

  @override
  bool operator ==(Object other) {
    return other is JsonArrayVM && other.elements == elements;
  }

  @override
  int get hashCode => elements.hashCode;
}

sealed class JsonObjectVM implements JsonValueVM {}

class NormalJsonObjectVM implements JsonObjectVM, JsonValueVM {
  LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> entryMap;

  String? shortString;

  NormalJsonObjectVM({required this.entryMap, this.shortString});

  @override
  bool operator ==(Object other) {
    return other is NormalJsonObjectVM && other.entryMap == entryMap;
  }

  @override
  int get hashCode => entryMap.hashCode;
}

class EnhancedJsonObjectVM implements JsonObjectVM, JsonValueVM {
  final LinkedHashMap<JsonObjectKeyVM, JsonValueVM> entryMap;

  EnhancedJsonObjectVM({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is EnhancedJsonObjectVM && other.entryMap == entryMap;
  }

  @override
  int get hashCode => entryMap.hashCode;
}

sealed class JsonObjectKeyVM {}

class JsonObjectKeyStringVM {
  final JsonStringVM value;

  JsonObjectKeyStringVM(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyStringVM && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
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
  int get hashCode => runtimeType.hashCode; // 所有实例共享同一个 hashCode
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
}

JsonValueVM convert(JsonValue value) {
  switch (value) {
    case JsonNull():
      return JsonNullVM();
    case JsonBool():
      return JsonBoolVM(value.value);
    case JsonString():
      var text = value.value;

      JsonValueVM? jsonValue;
      if (text.length > 20 && (text[0] == '[' || text[0] == '{')) {
        try {
          var parsedValue = Parser.parse(text);
          jsonValue = convert(parsedValue);
        } catch (e) {}
      }

      return JsonStringVM(rawText: value.rawText, parsed: jsonValue);
    case JsonNumber():
      return JsonNumberVM(rawText: value.rawText, value: value.value);
    case JsonArray():
      var newElements = value.elements.map((e) => convert(e)).toList();
      return JsonArrayVM(elements: newElements);
    case NormalJsonObject():
      return _convertNormalObject(value);
    case EnhancedJsonObject():
      return _convertEnhancedObject(value);
  }
}

JsonObjectVM _convertNormalObject(NormalJsonObject value) {
  LinkedHashMap<JsonObjectKeyStringVM, JsonValueVM> newMap = LinkedHashMap();
  value.entryMap.forEach((entryKey, entryValue) {
    var newKey = JsonObjectKeyStringVM(
      JsonStringVM(rawText: entryKey.value.rawText),
    );
    newMap[newKey] = convert(entryValue);
  });
  return NormalJsonObjectVM(entryMap: newMap);
}

JsonObjectVM _convertEnhancedObject(EnhancedJsonObject value) {
  LinkedHashMap<JsonObjectKeyVM, JsonValueVM> newMap = LinkedHashMap();
  value.entryMap.forEach((entryKey, entryValue) {
    JsonObjectKeyVM newKey = switch (entryKey) {
      JsonObjectKeyString() =>
        JsonObjectKeyStringVM(JsonStringVM(rawText: entryKey.value.rawText))
            as JsonObjectKeyVM,
      JsonObjectKeyNumber() => JsonObjectKeyNumberVM(
        JsonNumberVM(
          rawText: entryKey.value.rawText,
          value: entryKey.value.value,
        ),
      ),
      JsonObjectKeyBool() => JsonObjectKeyBoolVM(
        JsonBoolVM(entryKey.value.value),
      ),
      JsonObjectKeyNull() => JsonObjectKeyNullVM(),
      JsonObjectKeyObject() => JsonObjectKeyObjectVM(
        _convertObject(entryKey.value),
      ),
    };
    newMap[newKey] = convert(entryValue);
  });
  return EnhancedJsonObjectVM(entryMap: newMap);
}

JsonObjectVM _convertObject(JsonObject value) {
  switch (value) {
    case NormalJsonObject():
      return _convertNormalObject(value);
    case EnhancedJsonObject():
      return _convertEnhancedObject(value);
  }
}



class ToStringHelper {
  bool whitespace;
  bool deepParse;
  StringBuffer buffer = StringBuffer();

  ToStringHelper({required this.whitespace, this.deepParse = false});

  void toStringKey(StringBuffer buffer, JsonObjectKeyVM entryKey) {
    switch (entryKey) {
      case JsonObjectKeyNumberVM():
        buffer.write(entryKey.value.rawText);
        break;
      case JsonObjectKeyBoolVM():
        buffer.write(entryKey.value.rawText);
        break;
      case JsonObjectKeyNullVM():
        buffer.write('null');
        break;
      case JsonObjectKeyObjectVM():
        toJsonString(buffer, entryKey.value);
        break;
    }
  }

  void toJsonString(StringBuffer buffer, JsonValueVM jsonValue) {
    switch (jsonValue) {
      case JsonNullVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonStringVM():
        var parsed = jsonValue.parsed;
        if (parsed != null && deepParse) {
          toJsonString(buffer, parsed);
        } else {
          buffer.write(jsonValue.rawText);
        }
        break;
      case JsonBoolVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonNumberVM():
        buffer.write(jsonValue.rawText);
        break;
      case JsonArrayVM():
        buffer.write('[');
        int idx = 1;
        for (var element in jsonValue.elements) {
          toJsonString(buffer, element);
          if (idx < jsonValue.elements.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write(']');
        break;
      case NormalJsonObjectVM():
        buffer.write('{');
        int idx = 1;
        for (var entry in jsonValue.entryMap.entries) {
          buffer.write(entry.key.value.rawText);
          buffer.write(':');
          if (whitespace) {
            buffer.write(' ');
          }
          toJsonString(buffer, entry.value);
          if (idx < jsonValue.entryMap.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write('}');
        break;
      case EnhancedJsonObjectVM():
        buffer.write('{');
        int idx = 1;
        for (var entry in jsonValue.entryMap.entries) {
          toStringKey(buffer, entry.key);
          // buffer.write(entry.key.value.rawText);
          buffer.write(':');
          if (whitespace) {
            buffer.write(' ');
          }
          toJsonString(buffer, entry.value);
          if (idx < jsonValue.entryMap.length) {
            buffer.write(',');
            if (whitespace) {
              buffer.write(' ');
            }
          }
          idx += 1;
        }
        buffer.write('}');
    }
  }
}

