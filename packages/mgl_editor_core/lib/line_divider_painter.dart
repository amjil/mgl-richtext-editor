import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'm_render_paragraph.dart';

class LineDividerPainter extends CustomPainter {
  final MongolRenderParagraph? renderBox; // Pass RenderObject directly to avoid GlobalKey lookup
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

    // TextPainter is the source of truth
    final textPainter = rb.textPainter;
    
    // Use Path for batched drawing
    final path = Path();
    final paint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 3.0;

    // Mongol layout: each line is a column; traverse lines via getLineBoundary
    int currentOffset = 0;
    while (currentOffset < text.length) {
      final lineRange = rb.getLineBoundary(TextPosition(offset: currentOffset));
      if (lineRange.start == lineRange.end) break;

      // Logical box for current line
      final selection = TextSelection(baseOffset: lineRange.start, extentOffset: lineRange.end);
      final boxes = rb.getBoxesForSelection(selection);
      
      if (boxes.isNotEmpty) {
        // In Mongol vertical layout, Rect.right is the divider; use max right of line boxes
        double maxRight = boxes.fold(0.0, (m, b) => math.max(m, b.right));
        double minY = boxes.fold(double.infinity, (m, b) => math.min(m, b.top));
        double maxY = boxes.fold(0.0, (m, b) => math.max(m, b.bottom));

        final startY = extendToLineEnd ? 0.0 : minY;
        final endY = extendToLineEnd ? size.height : maxY;

        // Draw dashed path
        double y = startY;
        while (y < endY) {
          path.moveTo(maxRight, y);
          y += dashHeight;
          path.lineTo(maxRight, math.min(y, endY));
          y += dashSpace;
        }
      }

      if (lineRange.end <= currentOffset) break; // prevent infinite loop
      currentOffset = lineRange.end;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LineDividerPainter old) {
    // Repaint only when renderBox or text changes
    return old.renderBox != renderBox || 
           old.text != text || 
           old.extendToLineEnd != extendToLineEnd;
  }
}