import 'package:flutter/material.dart';

class StatProgressBar extends StatelessWidget {
  final String? label;
  final double value;
  final Color color;

  const StatProgressBar({
    super.key,
    this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        LinearProgressIndicator(
          value: value / 100,
          color: color,
          backgroundColor: color.withOpacity(0.2),
          minHeight: 6,
        ),
      ],
    );
  }
}
