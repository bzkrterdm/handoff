import 'package:flutter/material.dart';

/// A round initial badge coloured by agent name, so "claude" and "codex"
/// are told apart at a glance across the list.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, required this.agent, this.size = 22});

  static const List<Color> _palette = [
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFDB2777),
    Color(0xFF2563EB),
  ];

  final String agent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(agent);
    final initial = agent.isEmpty ? '?' : agent[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }

  static Color colorFor(String agent) {
    final hash = agent.toLowerCase().codeUnits.fold(0, (a, b) => a * 31 + b);

    return _palette[hash.abs() % _palette.length];
  }
}
