import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final double progress;
  const ProgressBar(this.progress);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("${(progress * 100).toStringAsFixed(1)}%"),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}
