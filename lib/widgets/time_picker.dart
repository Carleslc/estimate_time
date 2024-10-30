import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/platform.dart';

void showTimePickerDialog(
  BuildContext context, {
  required Function material,
  required Function ios,
}) {
  // TODO: Add Settings page with preferred time picker selector
  if (context.platform == TargetPlatform.iOS) {
    ios();
  } else {
    material();
  }
}

Future<TimeOfDay?> showTimePickerMaterial({
  required BuildContext context,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  TimeOfDay? initialTime,
  String? helpText,
  String? confirmText,
  bool format24Hours = true,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime ?? TimeOfDay(hour: 0, minute: 0),
    initialEntryMode: initialEntryMode,
    orientation: MediaQuery.orientationOf(context),
    hourLabelText: 'Horas',
    minuteLabelText: 'Minutos',
    helpText: helpText,
    confirmText: confirmText ?? 'Aceptar'.toUpperCase(),
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: format24Hours),
        child: child!,
      );
    },
  );
}

void showTimePickerCupertino({
  required BuildContext context,
  required void Function(Duration pickDuration) onTimerDurationChanged,
  CupertinoTimerPickerMode mode = CupertinoTimerPickerMode.hm,
  Duration initialTimerDuration = Duration.zero,
  int minuteInterval = 1,
  int secondInterval = 1,
  Color color = Colors.white,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (_) => Container(
      height: 250,
      color: color,
      child: CupertinoTimerPicker(
        mode: mode,
        minuteInterval: minuteInterval,
        secondInterval: secondInterval,
        initialTimerDuration: initialTimerDuration,
        onTimerDurationChanged: onTimerDurationChanged,
      ),
    ),
  );
}
