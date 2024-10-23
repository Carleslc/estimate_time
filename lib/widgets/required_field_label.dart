import 'package:flutter/material.dart';

class RequiredFieldLabel extends StatelessWidget {
  final String? labelText;
  final Widget? labelWidget;
  final Widget? indicatorWidget;
  late final String? indicator;

  RequiredFieldLabel({
    super.key,
    this.labelText,
    this.labelWidget,
    String? indicator,
    this.indicatorWidget,
  }) {
    // Either labelText or labelWidget is required, but not both
    assert((labelText != null && labelWidget == null) ||
        (labelWidget != null && labelText == null));
    // Ensure only one of indicator or indicatorWidget is provided, if any
    assert(indicator == null || indicatorWidget == null);
    this.indicator = indicator ?? '*';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Expanded label
        Row(
          children: [
            labelWidget ?? Text(labelText!),
          ],
        ),
        // Required indicator
        Positioned(
          right: 0,
          top: 1,
          child: indicatorWidget ??
              Text(
                indicator!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
        ),
      ],
    );
  }
}
