import 'dart:collection';

import 'json_parser_options.dart';
import 'json_tokenizer.dart';
import 'json_value.dart';

class JsonParser {
  final StringInterner _strInterner = StringInterner();
  final JsonTokenizer _tokenizer;
  final JsonParseOptions _options;

  JsonParser(this._tokenizer, this._options);

  static JsonValue parse(String text, {JsonParseOptions? options}) {
    options ??= JsonParseOptions.strict();
    final tokenizer = JsonTokenizer(text, options: options);
    final parser = JsonParser(tokenizer, options);
    return parser._parseValue();
  }

  JsonValue _parseValue({Token? peekedToken}) {
    final token = peekedToken ?? _tokenizer.nextToken();

    if (token == null) {
      throw FormatException("Unexpected end of input");
    }

    switch (token.type) {
      case TokenType.string:
        return JsonString(rawText: token.rawText, value: token.string);
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
    final elements = <JsonValue>[];

    bool needComma = false;
    while (true) {
      Token? token = _tokenizer.nextToken();
      if (token == null) {
        throw FormatException('Unexpected end of input in array');
      }
      if (token.type == TokenType.endArray) {
        break;
      }

      // comma
      if (needComma) {
        if (token.type == TokenType.comma) {
          token = _tokenizer.nextToken();
          if (token == null) {
            throw FormatException(
              'Unexpected end of input after comma in array',
            );
          }
        } else {
          throw FormatException('Expected , or ] after array element');
        }
      } else {
        needComma = true;
      }

      // value
      elements.add(_parseValue(peekedToken: token));
    }
    return JsonArray(elements: elements);
  }

  JsonObject _parseObject() {
    final entryMap = LinkedHashMap<JsonObjectKeyString, JsonValue>();
    bool needComma = false;
    while (true) {
      Token? token = _tokenizer.nextToken();
      if (token == null) {
        throw FormatException('Unexpected end of input in object');
      }
      if (token.type == TokenType.endObject) {
        break;
      }

      // comma
      if (needComma) {
        if (token.type == TokenType.comma) {
          token = _tokenizer.nextToken();
          if (token == null) {
            throw FormatException(
              'Unexpected end of input after comma in object',
            );
          }
        } else {
          throw FormatException('Expected , or } after value in object');
        }
      } else {
        needComma = true;
      }

      // key
      if (token.type != TokenType.string) {
        if (_options.allowExtendedKeyType) {
          return _continueParseExtendedObject(entryMap, token);
        } else {
          throw FormatException('Expecting a string for object key');
        }
      }
      final keyStringValue = token.string;
      final key = JsonObjectKeyString(
        JsonString(
          rawText: _strInterner.intern(token.rawText),
          value:
              keyStringValue == null
                  ? null
                  : _strInterner.intern(keyStringValue),
        ),
      );

      // colon
      final Token? colonToken = _tokenizer.nextToken();
      if (colonToken?.type != TokenType.colon) {
        throw FormatException('Expected : after key in object literal');
      }

      // value
      final value = _parseValue();
      final oldValue = entryMap[key];
      if (oldValue != null) {
        throw FormatException('Duplicate key: ${key.value}');
      }
      entryMap[key] = value;
    }
    return NormalJsonObject(entryMap: entryMap);
  }

  JsonObject _continueParseExtendedObject(
    LinkedHashMap<JsonObjectKeyString, JsonValue> parsedEntryMap,
    Token accessedToken,
  ) {
    final extendedMap = LinkedHashMap<JsonObjectKey, JsonValue>();
    for (final entry in parsedEntryMap.entries) {
      extendedMap[entry.key] = entry.value;
    }

    Token? token = accessedToken;
    while (true) {
      if (token == null) {
        throw FormatException('Unexpected end of input after comma in object');
      }

      // key
      final key = _parseJsonObjectKey(token);

      // colon
      final colonToken = _tokenizer.nextToken();
      if (colonToken?.type != TokenType.colon) {
        throw FormatException("Expected ':' after key in ExtendedJsonObject");
      }

      // value
      final value = _parseValue();
      final oldValue = extendedMap[key];
      if (oldValue != null) {
        throw FormatException('Duplicate key: $key');
      }
      extendedMap[key] = value;

      // comma or endObject
      token = _tokenizer.nextToken();
      if (token == null) {
        throw FormatException('Unexpected end of input in object');
      }
      if (token.type == TokenType.endObject) {
        break;
      } else if (token.type == TokenType.comma) {
        token = _tokenizer.nextToken();
      } else {
        throw FormatException('Expected , or } after value in object');
      }
    }
    return ExtendedJsonObject(entryMap: extendedMap);
  }

  JsonObjectKey _parseJsonObjectKey(Token keyToken) {
    switch (keyToken.type) {
      case TokenType.string:
        return JsonObjectKeyString(
          JsonString(rawText: keyToken.rawText, value: keyToken.string),
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
      //   key = JsonObjectKeyArray(_parseArray());
      //   break;
      default:
        throw FormatException(
          "Invalid key type in JSON object: ${keyToken.type}",
        );
    }
  }
}

class StringInterner {
  final Map<String, String> _cache = {};

  String intern(String input) {
    return _cache.putIfAbsent(input, () => input);
  }
}
