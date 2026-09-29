import 'package:flutter/material.dart';

/// A thin rounded progress track. Turns green when complete.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.done,
    required this.total,
    this.height = 5,
  });

  final int done;
  final int total;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = total == 0 ? 0.0 : done / total;
    final isComplete = total > 0 && done == total;
    final color = isComplete ? const Color(0xFF16A34A) : scheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          color: color,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
