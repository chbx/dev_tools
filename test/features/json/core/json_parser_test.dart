import 'dart:collection';

import 'package:dev_tools/features/json/core/json_parser.dart';
import 'package:dev_tools/features/json/core/json_parser_options.dart';
import 'package:dev_tools/features/json/core/json_value.dart';
import 'package:flutter_test/flutter_test.dart';

import 'json_matcher.dart';

void main() {
  group('JSON Parser Tests - String', () {
    test('Single String', () {
      expect(JsonParser.parse('"JSON"'), isJsonValue(_plainJsonString('JSON')));
    });

    test('Strings', () {
      expect(
        JsonParser.parse(
          r'["","JSON","\"\\\r\n\t","\u4e2d"]',
          options: JsonParseOptions.strict(
            backSlashEscapeType: BackSlashEscapeType.escapeAll,
          ),
        ),
        isJsonValue(
          JsonArray(
            elements: [
              JsonString(rawText: '""', value: null),
              JsonString(rawText: '"JSON"', value: null),
              JsonString(rawText: r'"\"\\\r\n\t"', value: '"\\\r\n\t'),
              JsonString(rawText: r'"\u4e2d"', value: '中'),
            ],
          ),
        ),
      );
    });

    test('Unescaped Strings', () {
      final value = JsonParser.parse(
        r'["","JSON","\"\\\r\n\t","\u4e2d"]',
        options: JsonParseOptions.strict(
          backSlashEscapeType: BackSlashEscapeType.onlyBackSlashAndDoubleQuote,
        ),
      );
      expect(
        value,
        isJsonValue(
          JsonArray(
            elements: [
              JsonString(rawText: '""', value: null),
              JsonString(rawText: '"JSON"', value: null),
              JsonString(rawText: r'"\"\\\r\n\t"', value: r'"\\r\n\t'),
              JsonString(rawText: r'"\u4e2d"', value: r'\u4e2d'),
            ],
          ),
        ),
      );
    });

    group("Invalid String", () {
      test('Unclosed String', () {
        expect(() => JsonParser.parse(r'"a'), throwsA(isA<Exception>()));
      });

      test('Unclosed String In Array', () {
        expect(() => JsonParser.parse(r'["a]'), throwsA(isA<Exception>()));
      });

      test('Invalid Unicode Escape', () {
        expect(
          () => JsonParser.parse(
            r'["\uqqqq"]',
            options: JsonParseOptions.strict(
              backSlashEscapeType: BackSlashEscapeType.escapeAll,
            ),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('Invalid Escape', () {
        expect(
          () => JsonParser.parse(
            r'"\q"',
            options: JsonParseOptions.strict(
              backSlashEscapeType: BackSlashEscapeType.escapeAll,
            ),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('Invalid Escape - Accept', () {
        expect(
          JsonParser.parse(
            r'"\q"',
            options: JsonParseOptions.strict(
              backSlashEscapeType: BackSlashEscapeType.escapeAll,
              allowBackSlashEscapingAnyCharacter: true,
            ),
          ),
          isJsonValue(JsonString(rawText: r'"\q"', value: r'\q')),
        );
      });

      test('Control Character In String', () {
        expect(() => JsonParser.parse('"a\n"'), throwsA(isA<Exception>()));
      });

      test('Control Character In String - Accept', () {
        expect(
          JsonParser.parse(
            '"a\n"',
            options: JsonParseOptions.strict(
              allowBackSlashEscapingAnyCharacter: true,
            ),
          ),
          isJsonValue(JsonString(rawText: '"a\n"', value: null)),
        );
      });
    });
  });

  group('JSON Parser Tests - Number', () {
    test('Numbers - Int', () {
      expect(
        JsonParser.parse(r'[0,-0,1,-1,123,-123]'),
        isJsonValue(
          JsonArray(
            elements: [
              JsonNumber(rawText: '0', value: JsonNumberValueInt(0)),
              JsonNumber(rawText: '-0', value: JsonNumberValueInt(0)),
              JsonNumber(rawText: '1', value: JsonNumberValueInt(1)),
              JsonNumber(rawText: '-1', value: JsonNumberValueInt(-1)),
              JsonNumber(rawText: '123', value: JsonNumberValueInt(123)),
              JsonNumber(rawText: '-123', value: JsonNumberValueInt(-123)),
            ],
          ),
        ),
      );
    });

    test('Numbers - Double', () {
      expect(
        JsonParser.parse(
          r'[0.0,0.1,-0.1,1.0,-1.0,1.1,-1.1,123.0,123.1,0.123,-0.123]',
        ),
        isJsonValue(
          JsonArray(
            elements: [
              JsonNumber(rawText: '0.0', value: JsonNumberValueFloat(0.0)),
              JsonNumber(rawText: '0.1', value: JsonNumberValueFloat(0.1)),
              JsonNumber(rawText: '-0.1', value: JsonNumberValueFloat(-0.1)),
              JsonNumber(rawText: '1.0', value: JsonNumberValueFloat(1.0)),
              JsonNumber(rawText: '-1.0', value: JsonNumberValueFloat(-1.0)),
              JsonNumber(rawText: '1.1', value: JsonNumberValueFloat(1.1)),
              JsonNumber(rawText: '-1.1', value: JsonNumberValueFloat(-1.1)),
              JsonNumber(rawText: '123.0', value: JsonNumberValueFloat(123.0)),
              JsonNumber(rawText: '123.1', value: JsonNumberValueFloat(123.1)),
              JsonNumber(rawText: '0.123', value: JsonNumberValueFloat(0.123)),
              JsonNumber(
                rawText: '-0.123',
                value: JsonNumberValueFloat(-0.123),
              ),
            ],
          ),
        ),
      );
    });

    test('Numbers - Exponent', () {
      expect(
        JsonParser.parse(
          r'[0e0,0e1,0e+1,1e1,1e2,1e+2,12e3,123e-2,-12e2,-12e-2]',
        ),
        isJsonValue(
          JsonArray(
            elements: [
              JsonNumber(rawText: '0e0', value: JsonNumberValueFloat(0.0)),
              JsonNumber(rawText: '0e1', value: JsonNumberValueFloat(0.0)),
              JsonNumber(rawText: '0e+1', value: JsonNumberValueFloat(0.0)),
              JsonNumber(rawText: '1e1', value: JsonNumberValueFloat(10.0)),
              JsonNumber(rawText: '1e2', value: JsonNumberValueFloat(100.0)),
              JsonNumber(rawText: '1e+2', value: JsonNumberValueFloat(100.0)),
              JsonNumber(rawText: '12e3', value: JsonNumberValueFloat(12000.0)),
              JsonNumber(rawText: '123e-2', value: JsonNumberValueFloat(1.23)),
              JsonNumber(rawText: '-12e2', value: JsonNumberValueFloat(-1200)),
              JsonNumber(rawText: '-12e-2', value: JsonNumberValueFloat(-0.12)),
            ],
          ),
        ),
      );
    });

    test('Numbers - Exponent 2', () {
      expect(
        JsonParser.parse(r'[12.3e2,1.2345e2,123.4e-2,-12.3e2,-123.4e-2]'),
        isJsonValue(
          JsonArray(
            elements: [
              JsonNumber(
                rawText: '12.3e2',
                value: JsonNumberValueFloat(1230.0),
              ),
              JsonNumber(
                rawText: '1.2345e2',
                value: JsonNumberValueFloat(123.45),
              ),
              JsonNumber(
                rawText: '123.4e-2',
                value: JsonNumberValueFloat(1.234),
              ),
              JsonNumber(
                rawText: '-12.3e2',
                value: JsonNumberValueFloat(-1230.0),
              ),
              JsonNumber(
                rawText: '-123.4e-2',
                value: JsonNumberValueFloat(-1.234),
              ),
            ],
          ),
        ),
      );
    });

    group('Invlaid Number', () {
      test('Leading Zero - Positive', () {
        expect(() => JsonParser.parse(r'01'), throwsA(isA<Exception>()));
      });

      test('Leading Zero - Negative', () {
        expect(() => JsonParser.parse(r'-01'), throwsA(isA<Exception>()));
      });

      test('Invalid Fraction', () {
        expect(() => JsonParser.parse(r'0.'), throwsA(isA<Exception>()));
      });

      test('Minus Space', () {
        expect(() => JsonParser.parse(r'[- 0]'), throwsA(isA<Exception>()));
      });

      test('Exponent', () {
        expect(() => JsonParser.parse(r'0e'), throwsA(isA<Exception>()));
      });

      test('Exponent-2', () {
        expect(() => JsonParser.parse(r'0e+'), throwsA(isA<Exception>()));
      });
    });
  });

  // true false null
  group('JSON Parser Tests - Literal', () {
    test('Literals', () {
      expect(
        JsonParser.parse(r'[true,false,null]'),
        isJsonValue(
          JsonArray(elements: [JsonBool(true), JsonBool(false), JsonNull()]),
        ),
      );
    });

    // TODO true\w should fail
  });

  group('JSON Parser Tests - Array', () {
    test('Arrays', () {
      expect(
        JsonParser.parse(r'[[],[1],[1,2]]'),
        isJsonValue(
          JsonArray(
            elements: [
              JsonArray(elements: []),
              JsonArray(
                elements: [
                  JsonNumber(rawText: '1', value: JsonNumberValueInt(1)),
                ],
              ),
              JsonArray(
                elements: [
                  JsonNumber(rawText: '1', value: JsonNumberValueInt(1)),
                  JsonNumber(rawText: '2', value: JsonNumberValueInt(2)),
                ],
              ),
            ],
          ),
        ),
      );
    });

    test('Invalid Array - Missing Comma', () {
      expect(() => JsonParser.parse('[true false]'), throwsA(isA<Exception>()));
    });

    test('Invalid Array - Invalid Comma', () {
      expect(() => JsonParser.parse('[,]'), throwsA(isA<Exception>()));
    });

    test('Invalid Array - Unclosed', () {
      expect(() => JsonParser.parse('['), throwsA(isA<Exception>()));
    });
  });

  group('JSON Parser Tests - Object', () {
    test('Objects', () {
      final text =
          r'{"empty":{},'
          r'"oneKey":{"key":"value"},'
          r'"twoKeys":{"key1":"value1","key2":"value2"}}';
      expect(
        JsonParser.parse(text),
        isJsonValue(
          NormalJsonObject(
            entryMap: LinkedHashMap.of({
              _stringKey('empty'): NormalJsonObject(entryMap: LinkedHashMap()),
              _stringKey('oneKey'): NormalJsonObject(
                entryMap: LinkedHashMap.of({
                  _stringKey('key'): _plainJsonString('value'),
                }),
              ),
              _stringKey('twoKeys'): NormalJsonObject(
                entryMap: LinkedHashMap.of({
                  _stringKey('key1'): _plainJsonString('value1'),
                  _stringKey('key2'): _plainJsonString('value2'),
                }),
              ),
            }),
          ),
        ),
      );
    });

    group('Invalid Object', () {
      test('Invalid Object - Missing Comma', () {
        expect(
          () => JsonParser.parse('{"key1": "value1" "key2": "value2"}'),
          throwsA(isA<Exception>()),
        );
      });
      test('Invalid Object - Missing Colon', () {
        expect(
          () => JsonParser.parse('{"key1" "value1"}'),
          throwsA(isA<Exception>()),
        );
      });
      test('Invalid Object - Unclosed', () {
        expect(() => JsonParser.parse('{'), throwsA(isA<Exception>()));
      });
      final invalidObjectKeyCases = [
        (desc: 'true', json: '{true: "value1"}'),
        (desc: 'false', json: '{false: "value1"}'),
        (desc: 'null', json: '{null: "value1"}'),
        (desc: 'number', json: '{123: "value1"}'),
        (desc: 'array', json: '{["array"]: "value1"}'),
        (desc: 'object', json: '{{"objectInKey": "fail"}: "value1"}'),
      ];
      for (final testCase in invalidObjectKeyCases) {
        test('Invalid Object Key - ${testCase.desc}', () {
          expect(
            () => JsonParser.parse(testCase.json),
            throwsA(isA<Exception>()),
          );
        });
      }
    });
  });

  group('JSON Parser Tests - Space', () {
    test('Space Around', () {
      expect(
        JsonParser.parse(' [ 1 ,\t\n { } , \r [ ] , true , "foo bar" ] '),
        isJsonValue(
          JsonArray(
            elements: [
              JsonNumber(rawText: '1', value: JsonNumberValueInt(1)),
              NormalJsonObject(entryMap: LinkedHashMap()),
              JsonArray(elements: []),
              JsonBool(true),
              _plainJsonString('foo bar'),
            ],
          ),
        ),
      );
    });

    test('Control Character In Space', () {
      expect(() => JsonParser.parse('[\u0002]'), throwsA(isA<Exception>()));
    });

    test('Control Character In Space - Accept', () {
      expect(
        JsonParser.parse(
          '[\u0002]',
          options: JsonParseOptions.strict(allowControlCharsInSpace: true),
        ),
        isJsonValue(JsonArray(elements: [])),
      );
    });
  });
}

JsonString _plainJsonString(String value) {
  final rawText = '"$value"';
  return JsonString(rawText: rawText, value: null);
}

JsonObjectKeyString _stringKey(String value) {
  return JsonObjectKeyString(_plainJsonString(value));
}
