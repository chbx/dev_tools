import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

class SearchTheme extends InheritedWidget {
  const SearchTheme({super.key, required this.theme, required super.child});

  final SearchThemeData theme;

  static SearchThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SearchTheme>()!.theme;
  }

  @override
  bool updateShouldNotify(SearchTheme oldWidget) {
    return theme.fontSize != oldWidget.theme.fontSize;
  }
}

class SearchThemeData with ScaleByFontThemeBase {
  SearchThemeData({required this.fontSize});

  @override
  final double fontSize;
}
