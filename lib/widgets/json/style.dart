import 'package:flutter/material.dart';

class ColorTheme {
  final Color? key;
  final Color? string;
  final Color? literal;
  final Color? number;
  final List<Color>? brackets;
  final Color? colon;
  final Color? comma;
  final Color? indent;
  final Color findMatchBackground;
  final Color activeFindMatchBackground;
  final Color shortString;
  final Color collapse;
  final Color hint;

  const ColorTheme({
    this.key,
    this.string,
    this.literal,
    this.number,
    this.brackets,
    this.colon,
    this.comma,
    this.indent,
    required this.findMatchBackground,
    required this.activeFindMatchBackground,
    required this.shortString,
    required this.collapse,
    required this.hint,
  });
}

const Color defaultIndentColor = Color(0xFFd3d3d3);
final ColorTheme defaultTheme = ColorTheme(
  key: Color(0xFF0451a5),
  string: Color(0xFFa31515),
  literal: Color(0xFF0000ff),
  number: Color(0xFF098658),
  brackets: [Color(0xFF0431fa), Color(0xFF319331), Color(0xFF7b3814)],
  colon: Color(0xFF3b3b3b),
  comma: Color(0xFF3b3b3b),
  indent: defaultIndentColor,
  // TODO
  findMatchBackground: Color.fromRGBO(234, 92, 0, 0.33),
  activeFindMatchBackground: Color(0xFFa8ac94),
  shortString: Colors.grey,
  collapse: Color(0xFF808080),
  hint: Colors.grey,
);
