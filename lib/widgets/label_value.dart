import 'package:flutter/material.dart';

class LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String? separator;

  const LabelValue({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.separator = ': ',
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${label}${separator}',
            style: labelStyle ?? Theme.of(context).textTheme.bodyMedium,
          ),
          TextSpan(
            text: value,
            style: valueStyle ??
                Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
