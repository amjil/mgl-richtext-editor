import 'package:flutter/material.dart';
import 'm_render_paragraph.dart';

class MongolCaretPainter extends CustomPainter {
  final GlobalKey textKey;
  final TextSelection selection;
  final Color caretColor;
  final double caretThickness;
  final Animation<double>? blinkAnimation;

  MongolCaretPainter({
    required this.textKey,
    required this.selection,
    this.caretColor = Colors.blue,
    this.caretThickness = 2.0,
    this.blinkAnimation,
  }) : super(repaint: blinkAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    MongolRenderParagraph? renderBox;
    try {
      renderBox = textKey.currentContext?.findRenderObject() as MongolRenderParagraph?;
    } catch (_) {
      renderBox = null;
    }
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return;

    // Only draw when selection is collapsed (caret mode)
    if (!selection.isCollapsed) return;

    // Blink: show roughly half the time.
    final blinkValue = blinkAnimation?.value;
    if (blinkValue != null && blinkValue < 0.5) return;

    final pos = TextPosition(offset: selection.baseOffset);
    
    // Mongol-specific caret offset; in MongolRenderParagraph this is a horizontal segment between characters
    final offset = renderBox.getOffsetForCaret(pos, Rect.zero);
    
    // Caret span (for vertical text, this is the column width).
    // When the block is empty, MongolTextPainter may report 0; derive a stable fallback from the effective text style.
    final baseStyle = renderBox.text.style;
    final scale = renderBox.textPainter.textScaleFactor;
    final fontSize = (baseStyle?.fontSize ?? 14.0) * scale;
    final heightMult = baseStyle?.height ?? 1.0;
    final derivedMinWidth = (fontSize * heightMult).clamp(12.0, 200.0);
    final double minCaretWidth = derivedMinWidth.isFinite ? derivedMinWidth : 20.0;
    final rawWidth = renderBox.getFullHeightForCaret(pos);
    final caretWidth = (rawWidth == null || rawWidth < minCaretWidth)
        ? minCaretWidth
        : rawWidth;

    final paint = Paint()
      ..color = caretColor
      ..strokeWidth = caretThickness
      ..style = PaintingStyle.fill;

    // Draw caret rect; dx, dy = top-left. For Mongol, caret is a horizontal line, height = thickness
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx, 
        offset.dy, 
        caretWidth, 
        caretThickness,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant MongolCaretPainter oldDelegate) {
    return oldDelegate.selection != selection || 
           oldDelegate.caretColor != caretColor ||
           oldDelegate.caretThickness != caretThickness ||
           oldDelegate.blinkAnimation != blinkAnimation;
  }
}