import 'package:dev_tools/features/json/json_viewer_page.dart';
import 'package:dev_tools/features/json/model/viewer_options.dart';
import 'package:dev_tools/features/json/widgets/json_viewer.dart';
import 'package:dev_tools/features/json/widgets/json_viewer_controller.dart';
import 'package:dev_tools/features/json/widgets/json_viewer_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helper.dart';

void main() {
  group('Nested Json', () {
    // {"nestedObject":"{\"inner\":\"bar\"}","deepNested":"[\"foo\",\"{\\\"deep\\\":\\\"foo\\\"}\"]","nestedArray":"[false,[]]","nestedString":"\"{\\\"inner2\\\":\\\"bar2\\\"}\""}
    // "{\"nestedObject\":\"{\\\"inner\\\":\\\"bar\\\"}\",\"deepNested\":\"[\\\"foo\\\",\\\"{\\\\\\\"deep\\\\\\\":\\\\\\\"foo\\\\\\\"}\\\"]\",\"nestedArray\":\"[false,[]]\",\"nestedString\":\"\\\"{\\\\\\\"inner2\\\\\\\":\\\\\\\"bar2\\\\\\\"}\\\"\"}"
    final jsonStringText =
        r'"{'
        r'\"nestedObject\":\"{\\\"inner\\\":\\\"bar\\\"}\",'
        r'\"deepNested\":\"[\\\"foo\\\",\\\"{\\\\\\\"deep\\\\\\\":\\\\\\\"foo\\\\\\\"}\\\"]\",'
        r'\"nestedArray\":\"[false,[]]\",'
        r'\"nestedString\":\"\\\"{\\\\\\\"inner2\\\\\\\":\\\\\\\"bar2\\\\\\\"}\\\"\"'
        r'}"';
    final jsonText =
        r'{'
        r'"nestedObject": "{\"inner\":\"bar\"}",'
        r'"deepNested": "[\"foo\",\"{\\\"deep\\\":\\\"foo\\\"}\"]",'
        r'"nestedArray": "[false,[]]",'
        r'"nestedString": "\"{\\\"inner2\\\":\\\"bar2\\\"}\""'
        r'}';
    // final expended1 =
    //     r'{'
    //     r'"nestedObject": {"inner": "bar"},'
    //     r'"deepNested": ["foo","{\"deep\":\"foo\"}"],'
    //     r'"nestedArray": [false,[ ]],'
    //     r'"nestedString": {"inner2": "bar2"}'
    //     r'}';
    final expended2 =
        r'{'
        r'"nestedObject": {"inner": "bar"},'
        r'"deepNested": ["foo",{"deep": "foo"}],'
        r'"nestedArray": [false,[ ]],'
        r'"nestedString": {"inner2": "bar2"}'
        r'}';
    final firstNestedString = r'"nestedObject": "{\"inner\":\"bar\"}",';
    final secondNestedString =
        r'"nestedString": "\"{\\\"inner2\\\":\\\"bar2\\\"}\""';
    final matchedString = '"inner": "bar"';
    final firstNestedSearch = r'"nestedObject": "{\"in';

    testWidgets('Nested Json Display Content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JsonViewer(
            controller: JsonViewerController(text: jsonText),
            themeData: defaultTheme,
          ),
        ),
      );

      final toggled = await expandAll(tester);
      final content = getViewerContent(tester);
      expect(content, expended2);
      expect(toggled, 5);
    });

    testWidgets('Nested Json - Disable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JsonViewer(
            controller: JsonViewerController(
              text: jsonText,
              options: JsonViewerOptions(parseNestedJsonString: false),
            ),
            themeData: defaultTheme,
          ),
        ),
      );

      await expandAll(tester);
      final content = getViewerContent(tester);
      expect(content, jsonText);
    });

    testWidgets('Parse Root String - Default Expand', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JsonViewer(
            controller: JsonViewerController(text: jsonStringText),
            themeData: defaultTheme,
          ),
        ),
      );
      final content = getViewerContent(tester);
      expect(content, jsonText);
    });

    testWidgets('Parse Root String - Collapse', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JsonViewer(
            controller: JsonViewerController(
              text: jsonStringText,
              options: JsonViewerOptions(autoParsedRootString: false),
            ),
            themeData: defaultTheme,
          ),
        ),
      );
      final content = getViewerContent(tester);
      expect(content, jsonStringText);
    });

    testWidgets('Nested Json Collapse&Expand', (WidgetTester tester) async {
      final controller = JsonViewerController(text: jsonText);
      await tester.pumpWidget(
        MaterialApp(home: JsonViewerPage(jsonViewerController: controller)),
      );

      controller.collapseAll();
      await tester.pump();
      final collapseContent = getViewerContent(tester);
      expect(collapseContent, '{...}');

      controller.expandAll();
      await tester.pump();
      final contentExpand = getViewerContent(tester);
      expect(contentExpand, jsonText);

      await expandAll(tester);
      controller.expandAll();
      await tester.pump();
      final contentExpandRespectCurrentState = getViewerContent(tester);
      expect(contentExpandRespectCurrentState, expended2);
    });

    group('Search', () {
      final firstMatchFinder = find.text(matchedString);
      final firstNestedStringFinder = find.text(firstNestedString);
      final secondNestedStringFinder = find.text(secondNestedString);

      testWidgets('Nested Json Search - Not Search Nested String', (
        WidgetTester tester,
      ) async {
        final controller = JsonViewerController(
          text: jsonText,
          options: JsonViewerOptions(searchNestedRawString: false),
        );
        await tester.pumpWidget(
          MaterialApp(home: JsonViewerPage(jsonViewerController: controller)),
        );
        final themeData =
            tester.widget<JsonViewer>(find.byType(JsonViewer)).themeData;

        final matchBackground = themeData.color.findMatchBackground;
        final activeBackground = themeData.color.activeFindMatchBackground;

        // search & first match
        controller.showOrFocusSearchField();
        await tester.pump();
        final searchFieldFinder = find.byType(TextField);
        await tester.enterText(searchFieldFinder, 'inner');
        await tester.pump();

        expect(
          controller.searchMatches.value.length,
          2,
          reason: 'find match count',
        );
        expect(
          find.descendant(
            of: find.byType(InnerJsonViewer),
            matching: firstNestedStringFinder,
          ),
          findsNothing,
          reason: 'first match: nested json string should be expanded',
        );
        expect(
          find.descendant(
            of: find.byType(InnerJsonViewer),
            matching: firstMatchFinder,
          ),
          findsOneWidget,
          reason: 'first match: expanded nested json string is matched',
        );
        expect(
          countTextWidgets(
            [tester.widget<Text>(firstMatchFinder)],
            'inner',
            activeBackground,
          ),
          1,
          reason: 'active match\'s content & style should have expected',
        );
        expect(
          find.byIcon(Icons.remove),
          findsNWidgets(2),
          reason:
              'first match: nested json string should be expanded, '
              'and only one nested json',
        );

        expect(
          secondNestedStringFinder,
          findsOneWidget,
          reason: 'second matched nested string should be collapsed',
        );
        expect(
          countTextWidgets(
            [tester.widget<Text>(secondNestedStringFinder)],
            'inner',
            matchBackground,
          ),
          0,
          reason: 'second nested json not match',
        );

        // next match
        controller.nextMatch();
        await tester.pump();
        expect(find.byIcon(Icons.remove), findsNWidgets(3));
        expect(secondNestedStringFinder, findsNothing);

        // search cross name & nested json string
        await tester.enterText(searchFieldFinder, firstNestedSearch);
        await tester.pump();
        expect(controller.searchMatches.value.length, 1);
        expect(firstNestedStringFinder, findsOneWidget);
      });

      testWidgets('Nested Json Search - Search Nested String', (
        WidgetTester tester,
      ) async {
        final controller = JsonViewerController(
          text: jsonText,
          options: JsonViewerOptions(searchNestedRawString: true),
        );
        await tester.pumpWidget(
          MaterialApp(home: JsonViewerPage(jsonViewerController: controller)),
        );
        final themeData =
            tester.widget<JsonViewer>(find.byType(JsonViewer)).themeData;

        final matchBackground = themeData.color.findMatchBackground;
        final activeBackground = themeData.color.activeFindMatchBackground;

        controller.showOrFocusSearchField();
        await tester.pump();
        final searchFieldFinder = find.byType(TextField);
        await tester.enterText(searchFieldFinder, 'inner');
        await tester.pump();

        expect(
          controller.searchMatches.value.length,
          4,
          reason: 'find match count',
        );
        expect(
          find.descendant(
            of: find.byType(InnerJsonViewer),
            matching: firstNestedStringFinder,
          ),
          findsOneWidget,
          reason:
              'first match: nested json string should be collapsed and matched',
        );
        expect(
          find.descendant(
            of: find.byType(InnerJsonViewer),
            matching: firstMatchFinder,
          ),
          findsNothing,
          reason: 'first match: nested json string should be collapsed',
        );
        expect(
          find.byIcon(Icons.remove),
          findsNWidgets(1),
          reason: 'first match: nested json string should be collapsed',
        );
        expect(
          countTextWidgets(
            [tester.widget<Text>(secondNestedStringFinder)],
            'inner',
            matchBackground,
          ),
          1,
        );

        // nest match : first nested json string expand
        controller.nextMatch();
        await tester.pump();
        expect(find.byIcon(Icons.remove), findsNWidgets(2));
        expect(firstNestedStringFinder, findsNothing);
        expect(firstMatchFinder, findsOneWidget);
        expect(secondNestedStringFinder, findsOneWidget);
        expect(
          countTextWidgets(
            [tester.widget<Text>(firstMatchFinder)],
            'inner',
            activeBackground,
          ),
          1,
        );

        // search cross name & nested json string
        await tester.enterText(searchFieldFinder, firstNestedSearch);
        await tester.pump();
        expect(controller.searchMatches.value.length, 1);
        expect(firstNestedStringFinder, findsOneWidget);
      });
    });
  });
}
