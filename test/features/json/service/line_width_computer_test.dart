import 'package:dev_tools/features/json/model/json_line.dart';
import 'package:dev_tools/features/json/service/line_width_computer.dart';
import 'package:dev_tools/features/json/view_model/view_line.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineWidthComputer', () {
    test('should calculate width for ASCII lines', () {
      final computer = LineWidthComputer();
      computer.updateRenderConfig(
        baseTextStyle: const TextStyle(fontSize: 14.0),
        indentWidth: 24.0,
        prefixWidth: 28.0,
      );

      final line = JsonLine(
        lineNumber: 0,
        content: '"key": "value"',
        indentLevel: 1,
        lineType: JsonLineType.value,
        tokens: [
          JsonLineToken('"key"', JsonTokenType.key),
          JsonLineToken(': ', JsonTokenType.colon),
          JsonLineToken('"value"', JsonTokenType.string),
        ],
        isBasicASCII: true,
      );

      final viewLine = ViewLine(
        viewLineNumber: 0,
        modelLineNumber: 0,
        modelLine: line,
      );

      final width = computer.getLineWidth(viewLine);
      expect(width, greaterThan(0));
      
      // Verify caching works
      final cachedWidth = computer.getLineWidth(viewLine);
      expect(cachedWidth, equals(width));
    });

    test('should handle non-ASCII lines', () {
      final computer = LineWidthComputer();
      computer.updateRenderConfig(
        baseTextStyle: const TextStyle(fontSize: 14.0),
        indentWidth: 24.0,
        prefixWidth: 28.0,
      );

      final line = JsonLine(
        lineNumber: 0,
        content: '"中文": "值"',
        indentLevel: 0,
        lineType: JsonLineType.value,
        tokens: [
          JsonLineToken('"中文"', JsonTokenType.key),
          JsonLineToken(': ', JsonTokenType.colon),
          JsonLineToken('"值"', JsonTokenType.string),
        ],
        isBasicASCII: false,
      );

      final viewLine = ViewLine(
        viewLineNumber: 0,
        modelLineNumber: 0,
        modelLine: line,
      );

      final width = computer.getLineWidth(viewLine);
      expect(width, greaterThan(0));
    });

    test('should invalidate cache when config changes', () {
      final computer = LineWidthComputer();
      computer.updateRenderConfig(
        baseTextStyle: const TextStyle(fontSize: 14.0),
        indentWidth: 24.0,
        prefixWidth: 28.0,
      );

      final line = JsonLine(
        lineNumber: 0,
        content: '"key": "value"',
        indentLevel: 1,
        lineType: JsonLineType.value,
        tokens: [
          JsonLineToken('"key"', JsonTokenType.key),
          JsonLineToken(': ', JsonTokenType.colon),
          JsonLineToken('"value"', JsonTokenType.string),
        ],
        isBasicASCII: true,
      );

      final viewLine = ViewLine(
        viewLineNumber: 0,
        modelLineNumber: 0,
        modelLine: line,
      );

      final width1 = computer.getLineWidth(viewLine);
      
      // Update config should invalidate cache
      computer.updateRenderConfig(
        baseTextStyle: const TextStyle(fontSize: 16.0), // Different font size
        indentWidth: 24.0,
        prefixWidth: 28.0,
      );

      final width2 = computer.getLineWidth(viewLine);
      expect(width2, isNot(equals(width1))); // Width should be different with new font size
    });

    test('should dispose resources properly', () {
      final computer = LineWidthComputer();
      computer.updateRenderConfig(
        baseTextStyle: const TextStyle(fontSize: 14.0),
        indentWidth: 24.0,
        prefixWidth: 28.0,
      );

      // Should not throw
      computer.dispose();
    });
  });
}
