import 'dart:ui';

/// Computes the top-left position for a square menu of [menuSize]
/// centered on [tapPosition], clamped so it stays within [screenSize]
/// with [padding] from each edge.
Offset clampMenuPosition({
  required Offset tapPosition,
  required Size screenSize,
  required double menuSize,
  required double padding,
}) {
  final half = menuSize / 2;
  final maxLeft = screenSize.width - menuSize - padding;
  final maxTop = screenSize.height - menuSize - padding;

  final left = (tapPosition.dx - half).clamp(padding, maxLeft);
  final top = (tapPosition.dy - half).clamp(padding, maxTop);

  return Offset(left, top);
}
