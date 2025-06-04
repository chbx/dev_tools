import 'package:flutter/material.dart';

import '../../../utils/utils.dart';
import '../../theme/theme.dart';
import '../common.dart';
import '../text_field.dart';
import 'search_button.dart';
import 'search_controller.dart';
import 'search_theme.dart';

class SearchField<T extends SearchControllerMixin> extends StatefulWidget {
  const SearchField({
    super.key,
    required this.searchController,
    this.searchFieldEnabled = true,
    this.shouldRequestFocus = false,
    this.supportsNavigation = true,
    this.searchFieldBorder,
    this.onClose,
    this.searchFieldWidth = defaultSearchFieldWidth,
    this.searchFieldHeight,
    int? maxLines = 1,
  }) : assert(maxLines != 0, "'maxLines' must not be 0"),
       _maxLines = maxLines;

  final T searchController;

  final double searchFieldWidth;

  final double? searchFieldHeight;

  final bool searchFieldEnabled;

  final bool shouldRequestFocus;

  final bool supportsNavigation;

  final InputBorder? searchFieldBorder;

  final VoidCallback? onClose;

  final int? _maxLines;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  @override
  Widget build(BuildContext context) {
    final searchField = StatelessSearchField(
      controller: widget.searchController,
      searchFieldEnabled: widget.searchFieldEnabled,
      shouldRequestFocus: widget.shouldRequestFocus,
      supportsNavigation: widget.supportsNavigation,
      onClose: widget.onClose,
      searchFieldHeight: widget.searchFieldHeight,
      searchFieldBorder: widget.searchFieldBorder,
      maxLines: widget._maxLines,
    );

    return widget._maxLines != 1
        ? searchField
        : SizedBox(
          width: widget.searchFieldWidth,
          height: widget.searchFieldHeight,
          child: searchField,
        );
  }
}

class StatelessSearchField<T extends SearchableDataMixin>
    extends StatelessWidget {
  const StatelessSearchField({
    super.key,
    required this.controller,
    required this.searchFieldEnabled,
    required this.shouldRequestFocus,
    this.searchFieldKey,
    this.label,
    this.decoration,
    this.supportsNavigation = false,
    this.onClose,
    this.onChanged,
    this.searchFieldBorder,
    this.prefix,
    this.suffix,
    this.style,
    this.searchFieldHeight,
    int? maxLines = 1,
  }) : assert(maxLines != 0, "'maxLines' must not be 0"),
       _maxLines = maxLines;

  final SearchControllerMixin<T> controller;

  final bool searchFieldEnabled;

  final bool shouldRequestFocus;

  final bool supportsNavigation;

  final String? label;

  final VoidCallback? onClose;

  final InputBorder? searchFieldBorder;

  final Widget? prefix;

  final Widget? suffix;

  final TextStyle? style;

  final InputDecoration? decoration;

  final GlobalKey? searchFieldKey;

  final double? searchFieldHeight;

  final ValueChanged<String>? onChanged;

  final int? _maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchTheme = SearchTheme.of(context);

    final regularTextStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: searchTheme.fontSize,
      fontFeatures: [const FontFeature.proportionalFigures()],
    );

    final subtleTextStyle = regularTextStyle.copyWith(
      color: const Color(0xFF919094),
    );

    final textStyle = style ?? regularTextStyle;

    void onChanged(String value) {
      this.onChanged?.call(value);
      controller.search = value;
      controller.searchFieldFocusNode?.requestFocus();
      // controller.searchFieldFocusNode?.requestFocus();
    }

    final searchField = FocusTraversalGroup(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              // statesController: _textFieldStatesController,
              key: searchFieldKey,
              // autofocus: true,
              enabled: searchFieldEnabled,
              focusNode: controller.searchFieldFocusNode,
              controller: controller.searchTextFieldController,
              style: textStyle,
              maxLines: _maxLines,
              onChanged: onChanged,
              decoration:
                  decoration ??
                  InputDecoration(
                    constraints: BoxConstraints(
                      minHeight:
                          searchFieldHeight ??
                          searchTheme.defaultTextFieldHeight,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: densePadding,
                    ),
                    border: searchFieldBorder ?? const OutlineInputBorder(),
                    hintText: 'Search',
                    hintStyle: subtleTextStyle,
                    labelText: label,
                    labelStyle: subtleTextStyle,
                    prefixIcon: Icon(
                      Icons.search,
                      size: searchTheme.defaultIconSize,
                    ),
                    prefix:
                        prefix != null
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                prefix!,
                                SizedBox(
                                  height:
                                      searchTheme.inputDecorationElementHeight,
                                  width: searchTheme.defaultIconSize,
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
          suffix ??
              _SearchFieldSuffix(
                controller: controller,
                supportsNavigation: supportsNavigation,
                onClose: () {
                  onClose?.call();
                  onChanged('');
                },
              ),
        ],
      ),
    );

    if (shouldRequestFocus) {
      controller.searchFieldFocusNode?.requestFocus();
    }

    return searchField;
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
