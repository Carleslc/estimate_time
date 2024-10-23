import 'package:flutter/foundation.dart';

void log(String s, {bool enabled = true}) {
  if (enabled && kDebugMode) {
    debugPrint(s);
  }
}
