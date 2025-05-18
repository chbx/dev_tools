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
  findMatchBackground: Colors.amberAccent.withValues(alpha: 0.6),
  activeFindMatchBackground: Colors.redAccent.withValues(alpha: 0.6),
  shortString: Colors.grey,
  collapse: Colors.grey,
);
