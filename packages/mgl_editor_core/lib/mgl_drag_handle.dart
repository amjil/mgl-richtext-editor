import 'package:flutter/material.dart';

/// A reusable, touch-friendly draggable handle for text selection and caret placement.
/// Rendered inside an Overlay, so it naturally wins all gesture arenas.
class MglDragHandle extends StatelessWidget {
  final Offset center;

  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final GestureDragCancelCallback? onPanCancel;

  const MglDragHandle({
    required this.center,
    this.onPanStart,
    required this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const double touchTargetRadius =
        24.0; // Invisible hit box for easy grabbing
    const double visualRadius = 6.0;

    return Positioned(
      left: center.dx - touchTargetRadius,
      top: center.dy - touchTargetRadius,
      width: touchTargetRadius * 2,
      height: touchTargetRadius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {}, // Absorb taps
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        onPanCancel: onPanCancel,
        child: Center(
          child: Container(
            width: visualRadius * 2,
            height: visualRadius * 2,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3, spreadRadius: 1)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
