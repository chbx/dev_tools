import 'package:flutter/foundation.dart';

@immutable
class JsonViewerOptions {
  final bool parseNestedJsonString;
  final bool autoParsedRootString;
  final bool searchNestedRawString;

  const JsonViewerOptions({
    this.parseNestedJsonString = true,
    this.autoParsedRootString = true,
    this.searchNestedRawString = false,
  });
}
