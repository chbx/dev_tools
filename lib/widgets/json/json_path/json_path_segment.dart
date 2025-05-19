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
}

class JsonPathSegmentSingleIndex extends JsonPathSegment {
  final int index;

  const JsonPathSegmentSingleIndex(this.index);
}

class JsonPathSegmentMultiIndex extends JsonPathSegment {
  final List<int> indexes;

  const JsonPathSegmentMultiIndex(this.indexes);
}

class JsonPathSegmentSingleName extends JsonPathSegment {
  final String name;

  const JsonPathSegmentSingleName(this.name);
}

class JsonPathSegmentMultiName extends JsonPathSegment {
  final List<String> names;

  const JsonPathSegmentMultiName(this.names);
}
