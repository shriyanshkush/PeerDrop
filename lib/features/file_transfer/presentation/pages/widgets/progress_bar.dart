import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.progress, {super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${(normalizedProgress * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: normalizedProgress),
      ],
    );
  }
}
