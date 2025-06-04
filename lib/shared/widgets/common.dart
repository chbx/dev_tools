import 'package:flutter/material.dart';

import '../theme/theme.dart';

// https://github.com/flutter/devtools
// packages/devtools_app_shared/lib/src/ui/constants.dart
final class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  });

  const PaddedDivider.thin({super.key})
    : padding = const EdgeInsets.only(bottom: 4.0);

  const PaddedDivider.noPadding({super.key}) : padding = EdgeInsets.zero;

  PaddedDivider.vertical({super.key, double padding = densePadding})
    : padding = EdgeInsets.symmetric(vertical: padding);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding, child: const Divider(thickness: 1.0));
  }
}
