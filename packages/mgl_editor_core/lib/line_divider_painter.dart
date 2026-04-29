import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'm_render_paragraph.dart';

class LineDividerPainter extends CustomPainter {
  final MongolRenderParagraph?
      renderBox; // Pass RenderObject directly to avoid GlobalKey lookup
  final String text;
  final bool extendToLineEnd;
  final Color dividerColor;

  LineDividerPainter({
    required this.renderBox,
    required this.text,
    this.extendToLineEnd = false,
    this.dividerColor = const Color(0x669E9E9E), // 0x66 = 0.4 opacity
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rb = renderBox;
    if (rb == null || !rb.hasSize || text.isEmpty) return;

    final path = Path();
    final paint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 3.0;

    // 🌟 THE ULTIMATE FIX: Geometry Clustering Approach
    // Instead of relying on buggy getLineBoundary(), we extract the physical
    // bounding boxes of ALL characters in the text at once.
    final selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    final boxes = rb.getBoxesForSelection(selection);

    if (boxes.isEmpty) return;

    // Group the boxes by their right edges to determine distinct vertical columns.
    final Set<int> uniqueRightEdges = {};
    double minY = double.infinity;
    double maxY = 0.0;

    for (final box in boxes) {
      // Find global top and bottom bounds of the text
      if (box.top < minY) minY = box.top;
      if (box.bottom > maxY) maxY = box.bottom;

      // Multiply by 10 and round to cluster close floating-point values together
      // This prevents drawing multiple lines for the same column due to sub-pixel differences
      uniqueRightEdges.add((box.right * 10).round());
    }

    // Sort the discovered column right-edges from left to right
    final List<double> columnsRightEdges =
        uniqueRightEdges.map((e) => e / 10.0).toList()..sort();

    final startY = extendToLineEnd ? 0.0 : minY;
    final endY = extendToLineEnd ? size.height : maxY;

    // Draw a dashed divider at the right edge of each column,
    // EXCEPT the very last one (which is the right-most boundary of the whole block).
    for (int i = 0; i < columnsRightEdges.length - 1; i++) {
      double maxRight = columnsRightEdges[i];

      // Draw dashed path for the current column
      double y = startY;
      while (y < endY) {
        path.moveTo(maxRight, y);
        y += dashHeight;
        path.lineTo(maxRight, math.min(y, endY));
        y += dashSpace;
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LineDividerPainter old) {
    // Repaint only when renderBox, text, or flags change
    return old.renderBox != renderBox ||
        old.text != text ||
        old.extendToLineEnd != extendToLineEnd;
  }
}
