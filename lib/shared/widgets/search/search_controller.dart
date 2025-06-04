import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

mixin SearchableDataMixin {
  bool isActiveSearchMatch = false;
  bool isSearchMatch = false;
}

mixin SearchControllerMixin<T extends SearchableDataMixin> {
  TextEditingController get searchTextFieldController =>
      _searchTextFieldController!;
  TextEditingController? _searchTextFieldController;

  ValueListenable<List<T>> get searchMatches => _searchMatches;
  final _searchMatches = _DangerValueNotifier<List<T>>([]);

  ValueListenable<bool> get searchInProgressNotifier => _searchInProgress;
  final _searchInProgress = ValueNotifier<bool>(false);

  String get search => _searchNotifier.value;
  final _searchNotifier = ValueNotifier<String>('');

  FocusNode? get searchFieldFocusNode => _searchFieldFocusNode;
  FocusNode? _searchFieldFocusNode;

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
      // TODO 防抖 & 异步
      final matches = matchesForSearch(
        _searchNotifier.value,
        searchPreviousMatches: searchPreviousMatches,
      );
      _updateMatches(matches);
    } else {
      _updateMatches([]);
    }
  }

  // no default impl
  List<T> matchesForSearch(String search, {bool searchPreviousMatches = false});

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
  final _activeSearchMatch = _DangerValueNotifier<T?>(null);

  /// 1-based index used for displaying matches status text (e.g. "2 / 15")
  final matchIndex = ValueNotifier<int>(0);

  void updateSearchMatchesSilently(List<T> newMatches) {
    final previousMatches = _searchMatches.value;
    assert(newMatches.length == previousMatches.length);
    _searchMatches.updateValueSilently(newMatches);
    final activeMatchIndex = matchIndex.value - 1;
    if (activeMatchIndex > 0 && activeMatchIndex < newMatches.length) {
      _activeSearchMatch.updateValueSilently(
        newMatches[activeMatchIndex]..isActiveSearchMatch = true,
      );
    }
  }

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

  void resetSearch() {
    _searchNotifier.value = '';
    _searchTextFieldController?.clear();
    refreshSearchMatches();
  }

  void toggleSearch() {
    _searchFieldFocusNode?.requestFocus();
  }

  void initSearch() {
    _searchTextFieldController =
        TextEditingController()..text = _searchNotifier.value;
    _searchFieldFocusNode = FocusNode(debugLabel: 'search-field');
  }

  void disposeSearch() {
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

class _DangerValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  _DangerValueNotifier(this._value) {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  @override
  T get value => _value;
  T _value;

  set value(T newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  void updateValueSilently(T newValue) {
    _value = newValue;
  }
}
