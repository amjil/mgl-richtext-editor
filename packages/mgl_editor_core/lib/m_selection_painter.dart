import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'm_render_paragraph.dart';

class MongolSelectionPainter extends CustomPainter {
  final GlobalKey textKey;
  final TextSelection selection;
  final bool hasFocus;
  final Color selectionColor;

  MongolSelectionPainter({
    required this.textKey,
    required this.selection,
    required this.hasFocus,
    this.selectionColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    MongolRenderParagraph? renderBox;
    try {
      renderBox = textKey.currentContext?.findRenderObject() as MongolRenderParagraph?;
    } catch (_) {
      renderBox = null;
    }
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    if (selection.isCollapsed) return;

    try {
      // Mongol-specific selection boxes
      final boxes = renderBox.getBoxesForSelection(selection);
      if (boxes.isEmpty) return;

      // Paint opacity by focus
      final double opacity = hasFocus ? 0.3 : 0.15;
      final Paint paint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      for (final box in boxes) {
        // Mongol vertical selection is narrow; use small radius
        final RRect rRect = RRect.fromRectAndRadius(
          box,
          const Radius.circular(3.0),
        );

        //
        paint.color = selectionColor.withOpacity(opacity);
        
        canvas.drawRRect(rRect, paint);
      }
    } catch (e) {
      // Avoid crash during layout
      debugPrint('MongolSelectionPainter error: $e');
    }
  }

  @override
  bool shouldRepaint(covariant MongolSelectionPainter oldDelegate) {
    return oldDelegate.selection != selection || 
           oldDelegate.hasFocus != hasFocus ||
           oldDelegate.selectionColor != selectionColor;
  }
}