import 'dart:math' as math;

import 'package:dev_tools/features/json/core/json_parser.dart';
import 'package:dev_tools/features/json/core/json_parser_options.dart';
import 'package:dev_tools/features/json/core/json_value.dart';
import 'package:dev_tools/features/json/widgets/dynamic_width.dart';
import 'package:dev_tools/features/json/widgets/json_viewer.dart';
import 'package:dev_tools/features/json/widgets/json_viewer_controller.dart';
import 'package:dev_tools/features/json/widgets/json_viewer_theme.dart';
import 'package:dev_tools/features/json/widgets/text_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const jsonString =
      '{'
      '"array-0":[],'
      '"array-1":[""],'
      '"array-2":[true,false],'
      '"array-3":["content-1","content-2","content-3"],'
      '"literal":[true,false,null],'
      '"object-0":{},'
      '"object-1":{"key-1":"content-1"},'
      '"object-2":{"":"","key-1":"content-1"},'
      '"nested-emptyObjectInArray":[{}],'
      '"nested-objectInArray":[{"key":"value"}],'
      '"numbers":[0,-1,1,234,1e2,23e-4,1.234,1.23e2],'
      r'"strings":["","a","ab","\\","\"","\t"]'
      '}';

  const extendedJsonObject =
      '{'
      '"key":"value",'
      'true:"key-bool-true",'
      'false:"key-bool-false",'
      'null:"key-null",'
      '123:"key-num-int",'
      '"array":[],'
      '{}:"empty object key",'
      '{"key-depth-1":"foo"}:"object key",'
      '{{"key-depth-2":"foo"}:["bar",{}]}:"nested object key",'
      '"normal-key-2":{}'
      '}';

  group('Widget - JsonViewer', () {
    final jsonViewerContentTestcases = [
      ("Normal Json Value", jsonString),
      ("Extended Object", extendedJsonObject),
    ];

    for (final (desc, json) in jsonViewerContentTestcases) {
      testWidgets('Json Viewer Content $desc', (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(Size(800, 2000));
        await tester.pumpWidget(
          MaterialApp(
            home: JsonViewer(
              controller: JsonViewerController(text: json),
              themeData: defaultTheme,
            ),
          ),
        );

        final buffer = StringBuffer();
        final widgets = tester.widgetList(find.byType(Text));
        for (final widget in widgets) {
          if (widget is Text) {
            buffer.write(widget.textSpan!.toPlainText());
          }
        }

        expect(
          JsonValue.toJsonString(
            JsonParser.parse(
              buffer.toString(),
              options: JsonParseOptions.loose(),
            ),
          ),
          json,
        );
      });
    }

    for (final (desc, json) in jsonViewerContentTestcases) {
      test('Controller - GetTextContent - $desc', () {
        final controller = JsonViewerController(text: json);
        final copied = controller.getTextContent();
        expect(copied, json);
      });
    }
  });

  testWidgets('JsonViewer Scroll Width', (WidgetTester tester) async {
    final longText1 = '"${'i' * 500}",';
    final longText2 = '"${'中' * 500}",';
    final json =
        '['
        '"foo",'
        'true,'
        '['
        '$longText1'
        '$longText2'
        '"bar"'
        '],'
        '123'
        ']';
    final controller = JsonViewerController(text: json);
    final theme = defaultTheme;
    await tester.pumpWidget(
      MaterialApp(home: JsonViewer(controller: controller, themeData: theme)),
    );

    // long text width
    final size = tester.getSize(find.byType(DynamicWidthContainer));
    final textStyle = TextStyle(
      fontFamily: theme.fontFamily,
      fontSize: theme.fontSize,
    );
    final maxTextWidth =
        theme.prefixWidth +
        2 * theme.indentWidth +
        math.max(
          calculateTextSpanWidth(TextSpan(text: longText1, style: textStyle)),
          calculateTextSpanWidth(TextSpan(text: longText2, style: textStyle)),
        );
    expect(size.width, greaterThanOrEqualTo(maxTextWidth));

    // collapsed width
    await tester.tap(find.byIcon(Icons.remove).last);
    await tester.pump();
    final collapsedSize = tester.getSize(find.byType(DynamicWidthContainer));
    final containerSize = tester.getSize(find.byType(JsonViewer));
    expect(collapsedSize.width, equals(containerSize.width));

    // expended width
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    final expendedSize = tester.getSize(find.byType(DynamicWidthContainer));
    expect(expendedSize.width, greaterThanOrEqualTo(maxTextWidth));
  });
}
