import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handle type: start (top of selection) or end (bottom)
enum MongolHandleType { start, end }

class MongolSelectionHandle extends StatelessWidget {
  final MongolHandleType type;
  final Offset globalPosition;
  final Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback? onDragEnd;

  const MongolSelectionHandle({
    super.key,
    required this.type,
    required this.globalPosition,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // Hit area; 40x40 minimum for touch
    const double handleSize = 40.0;
    
    return GestureDetector(
      onPanUpdate: (details) {
        // Haptic feedback
        HapticFeedback.selectionClick();
        onDragUpdate(details);
      },
      onPanEnd: (_) => onDragEnd?.call(),
      child: Container(
        width: handleSize,
        height: handleSize,
        color: Colors.transparent,
        child: CustomPaint(
          painter: _HandlePainter(
            type: type,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Painter for vertical text handles
class _HandlePainter extends CustomPainter {
  final MongolHandleType type;
  final Color color;

  _HandlePainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final double centerX = size.width / 2;
    final double circleRadius = 6.0;
    final double lineWidth = 14.0;
    final double lineHeight = 2.0;

    if (type == MongolHandleType.start) {
      // Start handle: circle at top, line below (character top edge)
      canvas.drawCircle(Offset(centerX, circleRadius), circleRadius, paint);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX, circleRadius + 6),
          width: lineWidth,
          height: lineHeight,
        ),
        paint,
      );
    } else {
      // End handle: line at top (character bottom edge), circle at bottom
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX, size.height - circleRadius - 6),
          width: lineWidth,
          height: lineHeight,
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(centerX, size.height - circleRadius),
        circleRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HandlePainter oldDelegate) => 
      oldDelegate.type != type || oldDelegate.color != color;
}