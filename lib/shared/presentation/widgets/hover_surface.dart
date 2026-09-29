import 'package:flutter/material.dart';

/// A rounded, clickable surface with hover and selected states — the one
/// interaction primitive the sidebar rows and the task cards share.
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.isSelected = false,
    this.radius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.selectedColor,
    this.showBorder = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isSelected;
  final double radius;
  final EdgeInsets padding;
  final Color? selectedColor;
  final bool showBorder;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selectedColor ?? scheme.primaryContainer;
    final background = widget.isSelected
        ? selected
        : _isHovered
        ? scheme.onSurface.withValues(alpha: 0.05)
        : Colors.transparent;
    final border = widget.showBorder
        ? Border.all(
            color: widget.isSelected
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.8),
          )
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: background,
            border: border,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
