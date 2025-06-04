import 'package:flutter/material.dart';

import '../../../utils/utils.dart';
import '../../theme/theme.dart';
import '../common.dart';
import '../text_field.dart';
import 'search_controller.dart';
import 'search_theme.dart';

class SearchNavigationControls extends StatelessWidget {
  const SearchNavigationControls(
    this.controller, {
    super.key,
    required this.onClose,
  });

  final SearchControllerMixin controller;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = SearchTheme.of(context);

    return ValueListenableBuilder<List<SearchableDataMixin>>(
      valueListenable: controller.searchMatches,
      builder: (context, matches, _) {
        final numMatches = matches.length;
        return ValueListenableBuilder<bool>(
          valueListenable: controller.searchInProgressNotifier,
          builder: (context, isSearchInProgress, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Opacity(
                //   opacity: isSearchInProgress ? 1 : 0,
                //   child: SizedBox(
                //     width: scaleByFontFactor(smallProgressSize),
                //     height: scaleByFontFactor(smallProgressSize),
                //     child:
                //         isSearchInProgress
                //             ? SmallCircularProgressIndicator(
                //               valueColor: AlwaysStoppedAnimation<Color?>(
                //                 Theme.of(context).regularTextStyle.color,
                //               ),
                //             )
                //             : const SizedBox(),
                //   ),
                // ),
                _matchesStatus(numMatches),
                SizedBox(
                  height: theme.inputDecorationElementHeight,
                  width: theme.defaultIconSize,
                  child: Transform.rotate(
                    angle: degToRad(90),
                    child: PaddedDivider.vertical(),
                  ),
                ),
                InputDecorationSuffixButton(
                  icon: Icons.keyboard_arrow_up,
                  onPressed: numMatches > 1 ? controller.previousMatch : null,
                ),
                InputDecorationSuffixButton(
                  icon: Icons.keyboard_arrow_down,
                  onPressed: numMatches > 1 ? controller.nextMatch : null,
                ),
                InputDecorationSuffixButton.close(
                  onPressed: () {
                    controller.searchTextFieldController.clear();
                    onClose?.call();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _matchesStatus(int numMatches) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.matchIndex,
      builder: (context, index, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: densePadding),
          child: Text(
            '$index/$numMatches',
            style: const TextStyle(fontSize: 12.0),
          ),
        );
      },
    );
  }
}
