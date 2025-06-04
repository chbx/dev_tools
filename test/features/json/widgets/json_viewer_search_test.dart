import 'package:dev_tools/features/json/json_viewer_page.dart';
import 'package:dev_tools/features/json/widgets/json_viewer.dart';
import 'package:dev_tools/features/json/widgets/json_viewer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helper.dart';

void main() {
  testWidgets('JsonViewer Search', (WidgetTester tester) async {
    final json =
        '{'
        '"key-1": "value-1",'
        '"key-2-1": "value-2-1",'
        '"key-2-2": "value-2-2",'
        '"key-2-3": "value-2-3"'
        '}';
    final controller = JsonViewerController(text: json);
    await tester.pumpWidget(
      MaterialApp(home: JsonViewerPage(jsonViewerController: controller)),
    );

    final searchFieldFinder = find.byType(TextField);

    final themeData =
        tester.widget<JsonViewer>(find.byType(JsonViewer)).themeData;
    final matchBackground = themeData.color.findMatchBackground;
    final activeBackground = themeData.color.activeFindMatchBackground;
    final allContentTextFinder = find.descendant(
      of: find.byType(InnerJsonViewer),
      matching: find.byType(Text),
    );

    // test shortcuts & text field
    expect(searchFieldFinder, findsNothing);
    final p = "macos";
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta, platform: p);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF, platform: p);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta, platform: p);
    await tester.pump();
    expect(searchFieldFinder, findsOneWidget);

    // test search content
    final searchText = 'value';
    await tester.enterText(searchFieldFinder, searchText);
    await tester.pump();
    expect(controller.searchMatches.value.length, 4);
    expect(
      countTextWidgets(
        [tester.widget<Text>(find.text('"key-1": "value-1",'))],
        searchText,
        activeBackground,
      ),
      1,
    );
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText,
        matchBackground,
      ),
      3,
    );

    // nextMatch
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(
      countTextWidgets(
        [tester.widget<Text>(find.text('"key-2-1": "value-2-1",'))],
        searchText,
        activeBackground,
      ),
      1,
    );
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText,
        matchBackground,
      ),
      3,
    );

    // collapse & expand & nextMatch
    controller.collapseAll();
    await tester.pump();
    controller.expandAll();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(
      countTextWidgets(
        [tester.widget<Text>(find.text('"key-2-2": "value-2-2",'))],
        searchText,
        activeBackground,
      ),
      1,
    );
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText,
        matchBackground,
      ),
      3,
    );

    // previousMatch
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pump();
    expect(
      countTextWidgets(
        [tester.widget<Text>(find.text('"key-2-1": "value-2-1",'))],
        searchText,
        activeBackground,
      ),
      1,
    );
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText,
        matchBackground,
      ),
      3,
    );

    // search previous
    final searchText2 = 'value-2';
    await tester.enterText(searchFieldFinder, searchText2);
    await tester.pump();
    expect(controller.searchMatches.value.length, 3);
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText2,
        activeBackground,
      ),
      1,
    );
    expect(
      countTextWidgets(
        tester.widgetList<Text>(allContentTextFinder).toList(),
        searchText2,
        matchBackground,
      ),
      2,
    );

    // close search
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(searchFieldFinder, findsNothing);
  });
}
