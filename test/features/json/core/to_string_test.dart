import 'package:dev_tools/features/json/core/json_parser.dart';
import 'package:dev_tools/features/json/core/json_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Json Value ToJsonString', () {
    final text =
        '{"literal":[true,false,null],'
        '"number":[1,-1,123,2e3],'
        '"string":"string value",'
        '"array-0":[],'
        '"array-1":["foo"],'
        '"array-2":["foo","bar"],'
        '"object-0":{},'
        '"object-1":{"foo":"bar"}}';
    expect(JsonValue.toJsonString(JsonParser.parse(text)), text);
  });

  test('Json Value ToJsonString - Array', () {
    final text = '[]';
    expect(JsonValue.toJsonString(JsonParser.parse(text)), text);
  });
}
