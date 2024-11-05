import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension PlatformExtension on BuildContext {
  TargetPlatform get platform => getPlatform(this);

  Locale get locale => getCurrentLocale(this);
}

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWeb => kIsWeb;

TargetPlatform getPlatform(BuildContext context) => Theme.of(context).platform;

Locale getCurrentLocale(BuildContext context) =>
    Localizations.localeOf(context);

String getSystemLocaleName() => Platform.localeName;
