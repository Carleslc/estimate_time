import 'package:flutter/material.dart';

/// Play / Pause
class TimerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isRunning;
  final Color runColor;
  final Color pauseColor;
  final double? iconSize;
  final String? label;

  TimerButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
    this.label,
    this.iconSize = 32,
    Color? runColor,
    Color? pauseColor,
  })  : runColor = runColor ?? Colors.green.shade400,
        pauseColor = pauseColor ?? Colors.red.shade400;

  Icon get icon => Icon(
        isRunning ? Icons.pause : Icons.play_arrow,
        size: iconSize,
      );

  ButtonStyle get style => IconButton.styleFrom(
        iconSize: iconSize,
        backgroundColor: isRunning ? pauseColor : runColor,
      );

  @override
  Widget build(BuildContext context) {
    return label != null
        ? FilledButton.icon(
            onPressed: onPressed,
            label: Text(
              label!,
              style: TextStyle(color: Colors.white),
            ),
            icon: icon,
            style: style,
          )
        : IconButton.filled(
            icon: icon,
            color: Colors.white,
            style: style,
            onPressed: onPressed,
          );
  }
}
