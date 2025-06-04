import 'package:dev_tools/features/json/widgets/json_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> expandAll(WidgetTester tester) async {
  int toggled = 0;
  final expandFinder = find.byIcon(Icons.add);
  while (true) {
    final widgets = tester.widgetList(expandFinder).toList();
    if (widgets.isEmpty) {
      break;
    }
    toggled += 1;
    await tester.tap(expandFinder.first);
    await tester.pump();
  }
  return toggled;
}

String getViewerContent(WidgetTester tester) {
  final buffer = StringBuffer();
  final widgets = tester.widgetList(
    find.descendant(
      of: find.byType(InnerJsonViewer),
      matching: find.byType(Text),
    ),
  );
  for (final widget in widgets) {
    if (widget is Text) {
      buffer.write(widget.textSpan!.toPlainText());
    }
  }
  return buffer.toString();
}

int countTextWidgets(Iterable<Text> textWidgets, String text, Color color) {
  int count = 0;
  for (final textWidget in textWidgets) {
    if (textWidget.data != null) {
      if (text == textWidget.data &&
          textWidget.style?.backgroundColor == color) {
        count += 1;
      }
    } else if (textWidget.textSpan != null) {
      count += _countTextSpans(textWidget.textSpan!, text, color);
    }
  }
  return count;
}

int _countTextSpans(InlineSpan textSpan, String text, Color color) {
  if (textSpan is! TextSpan) {
    return 0;
  }
  if (textSpan.children != null) {
    int count = 0;
    for (final childSpan in textSpan.children!) {
      count += _countTextSpans(childSpan, text, color);
    }
    return count;
  } else {
    if (textSpan.text == text && textSpan.style?.backgroundColor == color) {
      return 1;
    } else {
      return 0;
    }
  }
}
