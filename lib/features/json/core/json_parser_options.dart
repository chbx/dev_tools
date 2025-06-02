enum BackSlashEscapeType {
  escapeAll,
  // TODO 递归解析转义时在特殊字符时有问题
  //  \\\u4e2d => \\u4e2d => \u4e2d   少了一个\
  //  实际应为  => \中
  onlyBackSlashAndDoubleQuote,
}

class JsonParseOptions {
  final BackSlashEscapeType backSlashEscapeType;
  final bool allowBackSlashEscapingAnyCharacter;

  final bool allowUnquotedControlChars;
  final bool allowControlCharsInSpace;

  // TODO allow unquoted field names
  final bool allowExtendedKeyType;

  JsonParseOptions.strict({
    this.backSlashEscapeType = BackSlashEscapeType.escapeAll,
    this.allowBackSlashEscapingAnyCharacter = false,
    this.allowUnquotedControlChars = false,
    this.allowControlCharsInSpace = false,
    this.allowExtendedKeyType = false,
  });

  JsonParseOptions.loose({
    this.backSlashEscapeType = BackSlashEscapeType.escapeAll,
    this.allowBackSlashEscapingAnyCharacter = true,
    this.allowUnquotedControlChars = true,
    this.allowControlCharsInSpace = true,
    this.allowExtendedKeyType = true,
  });
}
