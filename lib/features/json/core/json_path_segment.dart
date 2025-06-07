class JsonPathSegment {
  const JsonPathSegment();
}

class JsonPathSegmentWildcard extends JsonPathSegment {
  static const JsonPathSegmentWildcard _instance =
      JsonPathSegmentWildcard._internal();

  const JsonPathSegmentWildcard._internal();

  factory JsonPathSegmentWildcard() {
    return _instance;
  }

  @override
  String toString() => 'JsonPathSegmentWildcard{*}';
}

class JsonPathSegmentSingleIndex extends JsonPathSegment {
  final int index;

  const JsonPathSegmentSingleIndex(this.index);

  @override
  String toString() => 'JsonPathSegmentSingleIndex{index: $index}';
}

class JsonPathSegmentMultiIndex extends JsonPathSegment {
  final List<int> indexes;

  const JsonPathSegmentMultiIndex(this.indexes);

  @override
  String toString() => 'JsonPathSegmentMultiIndex{indexes: $indexes}';
}

class JsonPathSegmentSingleName extends JsonPathSegment {
  final String name;

  const JsonPathSegmentSingleName(this.name);

  @override
  String toString() => 'JsonPathSegmentSingleName{name: $name}';
}

class JsonPathSegmentMultiName extends JsonPathSegment {
  final List<String> names;

  const JsonPathSegmentMultiName(this.names);

  @override
  String toString() => 'JsonPathSegmentMultiName{names: $names}';
}
