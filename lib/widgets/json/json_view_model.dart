import 'dart:collection';

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
