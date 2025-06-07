class ASCII {
  // @formatter:off
  // dart format off
  static const tab = 0x09;            // \t
  static const newline = 0x0A;        // \n
  static const carriageReturn = 0x0D; // \r
  static const space = 0x20;          // ' '
  static const doubleQuote = 0x22;    // "
  static const dollar = 0x24;         // $
  static const wildcard = 0x2A;       // *
  static const plus = 0x2B;           // +
  static const comma = 0x2C;          // ,
  static const minus = 0x2D;          // -
  static const dot = 0x2E;            // .
  static const slash = 0x2F;          // /
  static const singleQuote = 0x27;    // '
  static const char0 = 0x30;          // 0
  static const char1 = 0x31;          // 1
  static const char2 = 0x32;
  static const char3 = 0x33;
  static const char4 = 0x34;
  static const char5 = 0x35;
  static const char6 = 0x36;
  static const char7 = 0x37;
  static const char8 = 0x38;
  static const char9 = 0x39;          // 9
  static const semiColon = 0x3A;      // :
  static const char_A = 0x41;
  static const char_E = 0x45;
  static const char_F = 0x46;
  static const char_Z = 0x5A;
  static const lbracket = 0x5B;       // [
  static const backSlash = 0x5C;      // \
  static const rbracket = 0x5D;       // ]
  static const underline = 0x5F;      // _
  static const char_a = 0x61;
  static const char_b = 0x62;
  static const char_z = 0x7A;
  static const char_e = 0x65;
  static const char_f = 0x66;
  static const char_l = 0x6C;
  static const char_n = 0x6e;
  static const char_r = 0x72;
  static const char_s = 0x73;
  static const char_t = 0x74;
  static const char_u = 0x75;
  static const objectOpen = 0x7B;     // {
  static const objectClose = 0x7D;    // }
  static const beyondAscii = 0x80;
  // dart format on
  // @formatter:on

  static bool isOneNine(int char) => char >= char1 && char <= char9;

  static bool isZeroNine(int char) => char >= char0 && char <= char9;

  static bool isCharE(int char) => char == char_e || char == char_E;

  static bool isAlpha(int c) =>
      (c >= char_a && c <= char_z) || (c >= char_A && c <= char_Z);
}
