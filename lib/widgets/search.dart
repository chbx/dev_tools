// https://github.com/flutter/devtools

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common.dart';

mixin SearchControllerMixin<T extends SearchableDataMixin> {
  TextEditingController get searchTextFieldController =>
      _searchTextFieldController!;
  TextEditingController? _searchTextFieldController;

  ValueListenable<List<T>> get searchMatches => _searchMatches;
  final _searchMatches = ValueNotifier<List<T>>([]);

  ValueListenable<bool> get searchInProgressNotifier => _searchInProgress;
  final _searchInProgress = ValueNotifier<bool>(false);

  String get search => _searchNotifier.value;
  final _searchNotifier = ValueNotifier<String>('');

  FocusNode? get searchFieldFocusNode => _searchFieldFocusNode;
  FocusNode? _searchFieldFocusNode;

  void init() {
    _searchTextFieldController =
        TextEditingController()..text = _searchNotifier.value;
    _searchFieldFocusNode = FocusNode(debugLabel: 'search-field');
  }

  set search(String value) {
    final previousSearchValue = _searchNotifier.value;
    final shouldSearchPreviousMatches =
        previousSearchValue.isNotEmpty &&
        value.toLowerCase().contains(previousSearchValue.toLowerCase());
    // TODO toLowerCase
    _searchNotifier.value = value;
    refreshSearchMatches(searchPreviousMatches: shouldSearchPreviousMatches);
  }

  void refreshSearchMatches({bool searchPreviousMatches = false}) {
    if (_searchNotifier.value.isNotEmpty) {
      final matches = matchesForSearch(
        _searchNotifier.value,
        searchPreviousMatches: searchPreviousMatches,
      );
      _updateMatches(matches);
    } else {
      _updateMatches([]);
    }
  }

  List<T> matchesForSearch(
    String search, {
    bool searchPreviousMatches = false,
  }) => throw UnimplementedError();

  void _updateMatches(List<T> matches) {
    for (final previousMatch in _searchMatches.value) {
      previousMatch.isSearchMatch = false;
    }
    for (final newMatch in matches) {
      newMatch.isSearchMatch = true;
    }
    if (matches.isEmpty) {
      matchIndex.value = 0;
    }
    if (matches.isNotEmpty && matchIndex.value == 0) {
      matchIndex.value = 1;
    }
    _searchMatches.value = matches;
    _updateActiveSearchMatch(false);
  }

  ValueListenable<T?> get activeSearchMatch => _activeSearchMatch;
  final _activeSearchMatch = ValueNotifier<T?>(null);

  /// 1-based index used for displaying matches status text (e.g. "2 / 15")
  final matchIndex = ValueNotifier<int>(0);

  void previousMatch() {
    var previousMatchIndex = matchIndex.value - 1;
    if (previousMatchIndex < 1) {
      previousMatchIndex = _searchMatches.value.length;
    }
    matchIndex.value = previousMatchIndex;
    _updateActiveSearchMatch(true);
  }

  void nextMatch() {
    var nextMatchIndex = matchIndex.value + 1;
    if (nextMatchIndex > _searchMatches.value.length) {
      nextMatchIndex = 1;
    }
    matchIndex.value = nextMatchIndex;
    _updateActiveSearchMatch(true);
  }

  void _updateActiveSearchMatch(bool fromNavigation) {
    // [matchIndex] is 1-based. Subtract 1 for the 0-based list [searchMatches].
    int activeMatchIndex = matchIndex.value - 1;
    if (activeMatchIndex < 0) {
      _activeSearchMatch.value?.isActiveSearchMatch = false;
      _activeSearchMatch.value = null;
      return;
    }
    if (searchMatches.value.isNotEmpty &&
        activeMatchIndex >= searchMatches.value.length) {
      activeMatchIndex = 0;
      matchIndex.value = 1; // first item because [matchIndex] us 1-based
    }

    _activeSearchMatch.value?.isActiveSearchMatch = false;
    _activeSearchMatch.value =
        searchMatches.value[activeMatchIndex]..isActiveSearchMatch = true;

    onMatchChanged(activeMatchIndex, fromNavigation);
  }

  void onMatchChanged(int index, bool fromNavigation) {}

  void toggleSearch() {
    _searchFieldFocusNode?.requestFocus();
  }

  void searchDispose() {
    _searchTextFieldController?.dispose();
    _searchMatches.dispose();
    _searchInProgress.dispose();
    _searchNotifier.dispose();
    _activeSearchMatch.dispose();
    matchIndex.dispose();

    _searchFieldFocusNode?.dispose();
    _searchFieldFocusNode = null;
  }
}

mixin SearchableDataMixin {
  bool isActiveSearchMatch = false;
  bool isSearchMatch = false;
}

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.searchFieldEnabled,
    this.supportsNavigation = false,
    this.label,
    this.onClose,
    this.prefix,
    this.suffix,
    this.style,
    this.decoration,
    this.onChanged,
    this.searchFieldHeight,
    this.maxLines = 1,
  });

  final SearchControllerMixin controller;

  final bool searchFieldEnabled;

  final bool supportsNavigation;

  final String? label;

  final VoidCallback? onClose;

  final Widget? prefix;

  final Widget? suffix;

  final TextStyle? style;

  final InputDecoration? decoration;

  final ValueChanged<String>? onChanged;

  final double? searchFieldHeight;

  final int maxLines;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final WidgetStatesController _textFieldStatesController =
      WidgetStatesController();

  @override
  void dispose() {
    _textFieldStatesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final regularTextStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: defaultFontSize,
      fontFeatures: [const FontFeature.proportionalFigures()],
    );
    final subtleTextStyle = regularTextStyle.copyWith(
      color: const Color(0xFF919094),
    );

    final textStyle = widget.style ?? regularTextStyle;

    void onChanged(String value) {
      this.widget.onChanged?.call(value);
      widget.controller.search = value;
      // controller.searchFieldFocusNode?.requestFocus();
    }

    return ListenableBuilder(
      listenable: _textFieldStatesController,
      builder: (context, child) {
        var colors = Theme.of(context).colorScheme;
        var states = _textFieldStatesController.value;
        BorderSide borderSide;
        if (states.contains(WidgetState.focused)) {
          borderSide = BorderSide(color: colors.primary, width: 2.0);
        } else if (states.contains(WidgetState.hovered)) {
          borderSide = BorderSide(color: colors.onSurface);
        } else {
          borderSide = BorderSide(color: colors.outline);
        }

        return Container(
          width: defaultSearchFieldWidth,
          decoration: BoxDecoration(
            border: Border.all(color: borderSide.color),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: child!,
        );
      },
      child: Row(
        children: [
          Expanded(
            child: TextField(
              statesController: _textFieldStatesController,
              // key: searchFieldKey,
              autofocus: true,
              enabled: widget.searchFieldEnabled,
              focusNode: widget.controller.searchFieldFocusNode,
              controller: widget.controller._searchTextFieldController,
              style: textStyle,
              maxLines: widget.maxLines,
              onChanged: onChanged,
              decoration:
                  widget.decoration ??
                  InputDecoration(
                    constraints: BoxConstraints(
                      minHeight:
                          widget.searchFieldHeight ?? defaultTextFieldHeight,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: densePadding,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      gapPadding: 0.0,
                    ),
                    hintText: 'Search',
                    hintStyle: subtleTextStyle,
                    labelText: widget.label,
                    labelStyle: subtleTextStyle,
                    prefixIcon: Icon(Icons.search, size: defaultIconSize),
                    prefix:
                        widget.prefix != null
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                widget.prefix!,
                                SizedBox(
                                  height: inputDecorationElementHeight,
                                  width: defaultIconSize,
                                  child: Transform.rotate(
                                    angle: degToRad(90),
                                    child: PaddedDivider.vertical(),
                                  ),
                                ),
                              ],
                            )
                            : null,
                    // suffix:,
                  ),
            ),
          ),
          widget.suffix ??
              _SearchFieldSuffix(
                controller: widget.controller,
                supportsNavigation: widget.supportsNavigation,
                onClose: () {
                  widget.onClose?.call();
                  onChanged('');
                },
              ),
          SizedBox(width: densePadding)
        ],
      ),
    );
  }
}

class _SearchFieldSuffix extends StatelessWidget {
  const _SearchFieldSuffix({
    required this.controller,
    this.supportsNavigation = false,
    this.onClose,
  });

  final SearchControllerMixin controller;
  final bool supportsNavigation;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return supportsNavigation
        ? SearchNavigationControls(controller, onClose: onClose)
        : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InputDecorationSuffixButton.close(
              onPressed: () {
                controller.searchTextFieldController.clear();
                onClose?.call();
              },
            ),
          ],
        );
  }
}

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
                  height: inputDecorationElementHeight,
                  width: defaultIconSize,
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
    // maybeWrapWithTooltip
    return SizedBox(
      height: inputDecorationElementHeight,
      // height: defaultIconSize,
      // height: 14,
      width: inputDecorationElementHeight + denseSpacing,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        iconSize: defaultIconSize,
        splashRadius: defaultIconSize,
        icon: Icon(icon),
      ),
    );
  }
}
