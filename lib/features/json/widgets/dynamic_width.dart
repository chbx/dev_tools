import 'package:flutter/widgets.dart';

class DynamicWidthContainer extends StatefulWidget {
  const DynamicWidthContainer({
    super.key,

    required this.height,
    required this.widthNotifier,
    required this.child,
  });

  final double height;
  final ValueNotifier<double> widthNotifier;
  final Widget child;

  @override
  State<DynamicWidthContainer> createState() => _DynamicWidthContainerState();
}

class _DynamicWidthContainerState extends State<DynamicWidthContainer> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.widthNotifier,
      builder: (context, child) {
        return SizedBox(
          width: widget.widthNotifier.value,
          height: widget.height,
          child: widget.child,
        );
      },
    );
  }
}
