import 'dart:collection';

import 'tokenizer.dart';

sealed class JsonValue {
  const JsonValue();
}

class JsonNull implements JsonValue {
  static const JsonNull _instance = JsonNull._internal();

  factory JsonNull() {
    return _instance;
  }

  const JsonNull._internal();

  String get rawText => "null";
}

class JsonBool implements JsonValue {
  final bool _value;
  static const JsonBool _true = JsonBool._internal(true);
  static const JsonBool _false = JsonBool._internal(false);

  factory JsonBool(bool value) {
    return value ? _true : _false;
  }

  const JsonBool._internal(this._value);

  String get rawText => _value ? "true" : "false";

  bool get value => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonBool && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class JsonString implements JsonValue {
  final String rawText;
  final String value;

  JsonString({required this.rawText, required this.value});

  @override
  bool operator ==(Object other) {
    return other is JsonString && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;
}

class JsonNumber implements JsonValue {
  final String rawText;
  final JsonNumberValue value;

  JsonNumber({required this.rawText, required this.value});

  @override
  bool operator ==(Object other) {
    return other is JsonNumber && other.rawText == rawText;
  }

  @override
  int get hashCode => rawText.hashCode;
}

class JsonArray implements JsonValue {
  final List<JsonValue> elements;

  JsonArray({required this.elements});

  @override
  bool operator ==(Object other) {
    return other is JsonArray && other.elements == elements;
  }

  @override
  int get hashCode => elements.hashCode;
}

sealed class JsonObject implements JsonValue {}

class NormalJsonObject implements JsonObject {
  final LinkedHashMap<JsonObjectKeyString, JsonValue> entryMap;

  NormalJsonObject({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is NormalJsonObject && other.entryMap == entryMap;
  }

  @override
  int get hashCode => entryMap.hashCode;
}

class EnhancedJsonObject implements JsonObject {
  final LinkedHashMap<JsonObjectKey, JsonValue> entryMap;

  EnhancedJsonObject({required this.entryMap});

  @override
  bool operator ==(Object other) {
    return other is EnhancedJsonObject && other.entryMap == entryMap;
  }

  @override
  int get hashCode => entryMap.hashCode;
}

sealed class JsonObjectKey {
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

class JsonObjectKeyString implements JsonObjectKey {
  final JsonString value;

  JsonObjectKeyString(this.value);

  @override
  bool operator ==(Object other) {
    return other is JsonObjectKeyString && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
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
  int get hashCode => runtimeType.hashCode; // 所有实例共享同一个 hashCode
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
}

class Parser {
  final Tokenizer _tokenizer;

  Parser(this._tokenizer);

  static JsonValue parse(String text) {
    var tokenizer = Tokenizer(text);
    var parser = Parser(tokenizer);
    return parser._parseValue();
  }

  JsonValue _parseValue({Token? peekedToken}) {
    Token? token = peekedToken ?? _tokenizer.nextToken();

    if (token == null) {
      throw FormatException("Unexpected end of input");
    }

    switch (token.type) {
      case TokenType.string:
        return JsonString(rawText: token.rawText, value: token.string!);
      case TokenType.number:
        return JsonNumber(rawText: token.rawText, value: token.number!);
      case TokenType.startObject:
        return _parseObject();
      case TokenType.startArray:
        return _parseArray();
      case TokenType.valueTrue:
        return JsonBool(true);
      case TokenType.valueFalse:
        return JsonBool(false);
      case TokenType.valueNull:
        return JsonNull();
      default:
        throw FormatException("Unexpected token type: ${token.type}");
    }
  }

  JsonArray _parseArray() {
    List<JsonValue> elements = [];

    do {
      Token? token = _tokenizer.nextToken();
      if (token == null) {
        throw Exception('Excepted comma or end of array');
      } else if (token.type == TokenType.endArray) {
        break;
      } else if (token.type == TokenType.comma) {
        token = _tokenizer.nextToken();
      }
      elements.add(_parseValue(peekedToken: token));
    } while (true);

    // while (token != null && token.type != TokenType.endArray) {
    //   elements.add(_parseValue(peekedToken: token));
    //
    //   // 跳过逗号
    //   if (token.type == TokenType.comma) {
    //     token = _tokenizer.nextToken(); // 跳过逗号
    //   }
    // }

    return JsonArray(elements: elements);
  }

  JsonObject _parseObject() {
    LinkedHashMap<JsonObjectKeyString, JsonValue> entryMap = LinkedHashMap();

    Token? token = _tokenizer.nextToken();

    bool isEnhanced = false;
    while (token != null && token.type != TokenType.endObject) {
      if (token.type != TokenType.string) {
        isEnhanced = true;
        break;
      }

      JsonObjectKeyString key = JsonObjectKeyString(
        JsonString(rawText: token.rawText, value: token.string!),
      );

      Token? colonToken = _tokenizer.nextToken();
      if (colonToken?.type != TokenType.colon) {
        throw FormatException("Expected ':' after key in object literal");
      }

      JsonValue value = _parseValue();

      var oldValue = entryMap[key];
      if (oldValue != null) {
        throw Exception('duplicate key: ${key.value.rawText}');
      }
      entryMap[key] = value;

      // 跳过逗号
      Token? nextToken = _tokenizer.nextToken();
      if (nextToken != null && nextToken.type == TokenType.comma) {
        token = _tokenizer.nextToken(); // 跳过逗号后继续解析下一个键值对
      } else {
        token = nextToken;
      }
    }
    if (!isEnhanced) {
      return NormalJsonObject(entryMap: entryMap);
    }

    LinkedHashMap<JsonObjectKey, JsonValue> enhancedMap = LinkedHashMap();

    // 如果entryList entryMap 有值，填充enhancedEntries enhancedMap
    for (var entry in entryMap.entries) {
      enhancedMap[entry.key] = entry.value;
    }

    // 剩余部分的EnhancedJsonObject
    // token = _tokenizer.nextToken(); // 从断点处继续解析
    while (token != null && token.type != TokenType.endObject) {
      JsonObjectKey key = _parseJsonObjectKey(token);

      Token? colonToken = _tokenizer.nextToken();
      if (colonToken?.type != TokenType.colon) {
        throw FormatException("Expected ':' after key in EnhancedJsonObject");
      }

      JsonValue value = _parseValue();

      var oldValue = entryMap[key];
      if (oldValue != null) {
        throw Exception('duplicate key: ${key}');
      }
      enhancedMap[key] = value;

      // 跳过逗号
      Token? nextToken = _tokenizer.nextToken();
      if (nextToken != null && nextToken.type == TokenType.comma) {
        token = _tokenizer.nextToken(); // 跳过逗号
      } else {
        token = nextToken;
      }
    }

    return EnhancedJsonObject(entryMap: enhancedMap);
  }

  JsonObjectKey _parseJsonObjectKey(Token keyToken) {
    switch (keyToken.type) {
      case TokenType.string:
        return JsonObjectKeyString(
          JsonString(rawText: keyToken.rawText, value: keyToken.string!),
        );
      case TokenType.number:
        return JsonObjectKeyNumber(
          JsonNumber(rawText: keyToken.rawText, value: keyToken.number!),
        );
      case TokenType.valueTrue:
        return JsonObjectKeyBool(JsonBool(true));
      case TokenType.valueFalse:
        return JsonObjectKeyBool(JsonBool(false));
      case TokenType.valueNull:
        return JsonObjectKeyNull();
      case TokenType.startObject:
        return JsonObjectKeyObject(_parseObject());
      // case TokenType.startArray:
      //   key = JsonObjectKeyArray(_parseArray()); // 假设新增了 JsonObjectKeyArray 类型
      //   break;
      default:
        throw FormatException(
          "Invalid key type in JSON object: ${keyToken.type}",
        );
    }
  }
}
