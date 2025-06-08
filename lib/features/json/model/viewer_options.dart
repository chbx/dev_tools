import 'package:flutter/foundation.dart';

@immutable
class JsonViewerOptions {
  final bool parseNestedJsonString;
  final bool autoParsedRootString;
  final bool searchNestedRawString;
  final bool parseFastJsonRef;
  final bool showMoneyHint;

  const JsonViewerOptions({
    this.parseNestedJsonString = true,
    this.autoParsedRootString = true,
    this.searchNestedRawString = false,
    this.parseFastJsonRef = true,
    this.showMoneyHint = true,
  });
}
