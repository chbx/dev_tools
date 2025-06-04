import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'search/search_theme.dart';

final class InputDecorationSuffixButton extends StatelessWidget {
  const InputDecorationSuffixButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  factory InputDecorationSuffixButton.clear({
    required VoidCallback? onPressed,
  }) => InputDecorationSuffixButton(
    icon: Icons.clear,
    onPressed: onPressed,
    tooltip: 'Clear',
  );

  factory InputDecorationSuffixButton.close({
    required VoidCallback? onPressed,
  }) => InputDecorationSuffixButton(
    icon: Icons.close,
    onPressed: onPressed,
    tooltip: 'Close',
  );

  factory InputDecorationSuffixButton.help({
    required VoidCallback? onPressed,
  }) => InputDecorationSuffixButton(
    icon: Icons.question_mark,
    onPressed: onPressed,
    tooltip: 'Help',
  );

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // TODO 与SearchTheme强相关
    final theme = SearchTheme.of(context);
    final inputDecorationElementHeight = theme.inputDecorationElementHeight;
    final defaultIconSize = theme.defaultIconSize;
    // maybeWrapWithTooltip
    return SizedBox(
      // height: inputDecorationElementHeight,
      height: inputDecorationElementHeight + denseSpacing,
      width: inputDecorationElementHeight + denseSpacing,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        iconSize: defaultIconSize,
        splashRadius: defaultIconSize,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      ),
    );
  }
}
