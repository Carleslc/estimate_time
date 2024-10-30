import 'dart:io';

import 'package:flutter/material.dart';

extension PlatformExtension on BuildContext {
  TargetPlatform get platform => getPlatform(this);

  Locale get locale => getCurrentLocale(this);
}

TargetPlatform getPlatform(BuildContext context) => Theme.of(context).platform;

Locale getCurrentLocale(BuildContext context) =>
    Localizations.localeOf(context);

String getSystemLocaleName() => Platform.localeName;
