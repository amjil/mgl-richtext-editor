import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  List<double>? _columnsRightEdges;
  double _minY = 0.0;
  double _maxY = 0.0;
  Size? _layoutSize;

  void _ensureGeometry() {
    final rb = renderBox;
    if (rb == null || !rb.hasSize || text.isEmpty) {
      _columnsRightEdges = const [];
      _layoutSize = null;
      return;
    }

    final layoutSize = rb.size;
    if (_columnsRightEdges != null && _layoutSize == layoutSize) {
      return;
    }

    final selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    final boxes = rb.getBoxesForSelection(selection);
    if (boxes.isEmpty) {
      _columnsRightEdges = const [];
      _layoutSize = layoutSize;
      return;
    }

    final Set<int> uniqueRightEdges = {};
    double minY = double.infinity;
    double maxY = 0.0;

    for (final box in boxes) {
      if (box.top < minY) minY = box.top;
      if (box.bottom > maxY) maxY = box.bottom;
      uniqueRightEdges.add((box.right * 10).round());
    }

    _columnsRightEdges = uniqueRightEdges.map((e) => e / 10.0).toList()
      ..sort();
    _minY = minY;
    _maxY = maxY;
    _layoutSize = layoutSize;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rb = renderBox;
    if (rb == null || !rb.hasSize || text.isEmpty) return;

    _ensureGeometry();
    final columnsRightEdges = _columnsRightEdges;
    if (columnsRightEdges == null || columnsRightEdges.length < 2) return;

    final path = Path();
    final paint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 3.0;

    final startY = extendToLineEnd ? 0.0 : _minY;
    final endY = extendToLineEnd ? size.height : _maxY;

    for (int i = 0; i < columnsRightEdges.length - 1; i++) {
      double maxRight = columnsRightEdges[i];
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
    final Size? newSize =
        (renderBox != null && renderBox!.hasSize) ? renderBox!.size : null;
    final Size? oldSize = (old.renderBox != null && old.renderBox!.hasSize)
        ? old.renderBox!.size
        : null;
    return old.renderBox != renderBox ||
        old.text != text ||
        old.extendToLineEnd != extendToLineEnd ||
        old.dividerColor != dividerColor ||
        newSize != oldSize;
  }
}
