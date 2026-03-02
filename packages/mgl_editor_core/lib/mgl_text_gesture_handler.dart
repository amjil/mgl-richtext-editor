import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'm_render_paragraph.dart';

/// Gesture handler for Mongol vertical text selection
class MglTextGestureHandler {
  final MongolRenderParagraph Function() getRenderParagraph;
  final TextSelection? currentSelection;
  final ValueChanged<TextSelection> onSelectionChanged;

  // Drag start offset so baseOffset stays fixed during drag
  int? _dragStartOffset;

  MglTextGestureHandler({
    required this.getRenderParagraph,
    required this.currentSelection,
    required this.onSelectionChanged,
  });

  /// Global to local offset in RenderBox
  Offset _getLocalOffset(Offset globalPosition) {
    final RenderBox renderBox = getRenderParagraph();
    return renderBox.globalToLocal(globalPosition);
  }

  /// 1. Tap: place caret
  void handleTapDown(TapDownDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    
    // Get position in vertical layout
    final TextPosition position = renderBox.getPositionForOffset(localOffset);

    // Collapsed selection (caret)
    onSelectionChanged(TextSelection.fromPosition(position));
  }

  /// 2. Double-tap: select word
  void handleDoubleTapDown(TapDownDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);
    
    // Word boundary
    final TextRange wordRange = renderBox.getWordBoundary(position);
    
    if (wordRange.isValid) {
      onSelectionChanged(
        TextSelection(
          baseOffset: wordRange.start,
          extentOffset: wordRange.end,
        ),
      );
    }
  }

  /// 3. Pan start: begin drag selection
  void handlePanStart(DragStartDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);

    // Store start offset
    _dragStartOffset = position.offset;

    onSelectionChanged(
      TextSelection(
        baseOffset: _dragStartOffset!,
        extentOffset: _dragStartOffset!,
      ),
    );
  }

  /// 4. Pan update: extend selection
  void handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartOffset == null) return;

    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);

    // Update extentOffset, keep baseOffset
    onSelectionChanged(
      TextSelection(
        baseOffset: _dragStartOffset!,
        extentOffset: position.offset,
      ),
    );
  }

  /// 5. Pan end
  void handlePanEnd(DragEndDetails details) {
    _dragStartOffset = null;
  }
}