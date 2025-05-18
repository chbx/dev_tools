import 'package:flutter/material.dart';

import 'constants.dart';

class DynamicSizeWidget extends StatefulWidget {
  const DynamicSizeWidget({
    super.key,

    required this.height,
    required this.maxWidthNotifier,
    required this.child,
  });

  final double height;
  final ValueNotifier<double> maxWidthNotifier;
  final Widget child;

  @override
  State<DynamicSizeWidget> createState() => _DynamicSizeWidgetState();
}

class _DynamicSizeWidgetState extends State<DynamicSizeWidget> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.maxWidthNotifier,
      builder: (context, child) {
        return SizedBox(
          width: widget.maxWidthNotifier.value,
          height: widget.height,
          child: widget.child,
        );
      },
    );
  }
}

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
