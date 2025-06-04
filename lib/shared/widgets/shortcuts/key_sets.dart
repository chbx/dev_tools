import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final searchInFileKeySet = LogicalKeySet(
  Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyF,
);
