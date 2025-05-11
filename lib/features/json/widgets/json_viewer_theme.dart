import 'package:flutter/widgets.dart';

const unscaledDefaultFontSize = 14.0;

class JsonViewerThemeData {
  JsonViewerThemeData({
    required this.color,
    required this.prefixWidth,
    required this.indentWidth,
    this.fontFamily,
    required this.fontSize,
    required this.spaceAfterIcon,
  }) : iconBoxSize = fontSize,
       iconSize = fontSize - 4,
       textStyle = _buildTextStyle(color);

  final JsonViewerColorTheme color;
  final JsonViewerTextStyle textStyle;

  final double prefixWidth;
  final double indentWidth;

  final String? fontFamily;
  final double fontSize;

  final double iconBoxSize;
  final double iconSize;
  final double spaceAfterIcon;

  get defaultRowHeight => scaleByFontFactor(20.0);

  double scaleByFontFactor(double original) {
    final themFontSize = fontSize;
    return (original * (themFontSize / unscaledDefaultFontSize))
        .roundToDouble();
  }

  static _buildTextStyle(JsonViewerColorTheme color) {
    return JsonViewerTextStyle(
      objectKey: TextStyle(color: color.objectKey),

      string: TextStyle(color: color.string),
      literal: TextStyle(color: color.literal),
      number: TextStyle(color: color.number),
      brackets: _buildBrackets(color.brackets),
      colon: TextStyle(color: color.colon),
      comma: TextStyle(color: color.comma),
      foldForeground: TextStyle(color: color.foldForeground),
      foldBackground: TextStyle(backgroundColor: color.foldBackground),
    );
  }

  static List<TextStyle>? _buildBrackets(List<Color>? brackets) {
    if (brackets == null) {
      return null;
    }
    return brackets.map((e) => TextStyle(color: e)).toList();
  }
}

class JsonViewerTextStyle {
  JsonViewerTextStyle({
    required this.objectKey,
    required this.string,
    required this.literal,
    required this.number,
    this.brackets,
    required this.colon,
    required this.comma,
    required this.foldForeground,
    required this.foldBackground,
  });

  final TextStyle objectKey;
  final TextStyle string;
  final TextStyle literal;
  final TextStyle number;
  final List<TextStyle>? brackets;
  final TextStyle colon;
  final TextStyle comma;
  final TextStyle foldForeground;
  final TextStyle foldBackground;
}

class JsonViewerColorTheme {
  const JsonViewerColorTheme({
    required this.objectKey,
    required this.string,
    required this.literal,
    required this.number,
    this.brackets,
    required this.colon,
    required this.comma,
    required this.indentLine,
    required this.foldForeground,
    required this.foldBackground,
  });

  final Color objectKey;
  final Color string;
  final Color literal;
  final Color number;
  final List<Color>? brackets;
  final Color colon;
  final Color comma;
  final Color indentLine;
  final Color foldForeground;
  final Color foldBackground;
}

const Color _defaultIndentLineColor = Color(0xFFd3d3d3);
const defaultColorThemeData = JsonViewerColorTheme(
  objectKey: Color(0xFF0451a5),
  string: Color(0xFFa31515),
  literal: Color(0xFF0000ff),
  number: Color(0xFF098658),
  brackets: [Color(0xFF0431fa), Color(0xFF319331), Color(0xFF7b3814)],
  colon: Color(0xFF3b3b3b),
  comma: Color(0xFF3b3b3b),
  indentLine: _defaultIndentLineColor,
  foldForeground: Color(0xFF808080),
  foldBackground: Color.fromRGBO(0xd4, 0xd4, 0xd4, 0.25),
);

final defaultTheme = JsonViewerThemeData(
  prefixWidth: 28.0,
  indentWidth: 24.0,
  fontFamily: null,
  fontSize: unscaledDefaultFontSize,
  spaceAfterIcon: 4,

  color: defaultColorThemeData,
);
