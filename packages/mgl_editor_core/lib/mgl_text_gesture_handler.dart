import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'm_render_paragraph.dart';

/// Gesture handler for Mongol vertical text selection
class MglTextGestureHandler {
  final MongolRenderParagraph Function() getRenderParagraph;
  final TextSelection? Function() getSelection;
  ValueChanged<TextSelection> onSelectionChanged;

  int? _dragStartOffset;

  // Virtual tracking point to bypass physical engine boundaries
  Offset? _virtualDragPos;

  // Local State Accumulators:
  // Prevents state reset bugs caused by asynchronous widget rebuilding
  int? _activeDragStart;
  int? _activeDragEnd;

  MglTextGestureHandler({
    required this.getRenderParagraph,
    required this.getSelection,
    required this.onSelectionChanged,
  });

  Offset _getLocalOffset(Offset globalPosition) {
    final RenderBox renderBox = getRenderParagraph();
    return renderBox.globalToLocal(globalPosition);
  }

  // ====================================================================
  // Standard Tap & Swipe Selection
  // ====================================================================

  void handleTapDown(TapDownDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);
    onSelectionChanged(TextSelection.fromPosition(position));
  }

  void handleDoubleTapDown(TapDownDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);
    final TextRange wordRange = renderBox.getWordBoundary(position);

    if (wordRange.isValid) {
      onSelectionChanged(TextSelection(
          baseOffset: wordRange.start, extentOffset: wordRange.end));
    }
  }

  void handlePanStart(DragStartDetails details) {
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);
    _dragStartOffset = position.offset;
    onSelectionChanged(TextSelection(
        baseOffset: _dragStartOffset!, extentOffset: _dragStartOffset!));
  }

  void handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartOffset == null) return;
    final renderBox = getRenderParagraph();
    final localOffset = _getLocalOffset(details.globalPosition);
    final position = renderBox.getPositionForOffset(localOffset);
    onSelectionChanged(TextSelection(
        baseOffset: _dragStartOffset!, extentOffset: position.offset));
  }

  void handlePanEnd(DragEndDetails details) {
    _dragStartOffset = null;
  }

  // ====================================================================
  // Handle Drag Logic (Virtual Delta Tracking + Dead-Zone Filter)
  // ====================================================================

  void handleCaretPanStart(DragStartDetails details) {
    final currentSelection = getSelection();
    if (currentSelection == null) return;
    final renderBox = getRenderParagraph();

    final caretOffsetLocal = renderBox.getOffsetForCaret(
        TextPosition(offset: currentSelection.baseOffset), Rect.zero);

    _virtualDragPos =
        Offset(caretOffsetLocal.dx + 5.0, caretOffsetLocal.dy + 5.0);
  }

  void handleCaretPanUpdate(DragUpdateDetails details) {
    if (_virtualDragPos == null) return;
    final renderBox = getRenderParagraph();

    _virtualDragPos = _virtualDragPos! + details.delta;

    final double clampedX =
        _virtualDragPos!.dx.clamp(0.0, renderBox.size.width);
    final double clampedY = _virtualDragPos!.dy
        .clamp(0.0, math.max(0.0, renderBox.size.height - 0.1));

    final position = renderBox.getPositionForOffset(Offset(clampedX, clampedY));
    int newOffset = position.offset;

    // ENGINE DEAD-ZONE BUGFIX (Newline Handling)
    final currentSelection = getSelection();
    if (newOffset == 0 &&
        (_virtualDragPos!.dx > 20.0 || _virtualDragPos!.dy > 20.0)) {
      if (currentSelection != null) {
        newOffset = currentSelection.baseOffset;
      }
    }

    onSelectionChanged(TextSelection.collapsed(offset: newOffset));
  }

  void handleHandlePanStart(DragStartDetails details, bool isStartHandle) {
    final currentSelection = getSelection();
    if (currentSelection == null) return;

    final renderBox = getRenderParagraph();
    final boxes = renderBox.getBoxesForSelection(currentSelection);
    if (boxes.isEmpty) return;

    // 1. Save the current stable selection state to internal variables
    _activeDragStart = currentSelection.start;
    _activeDragEnd = currentSelection.end;

    // 2. Initialize virtual tracking point
    if (isStartHandle) {
      final box = boxes.first;
      _virtualDragPos = Offset(box.left + (box.width / 2.0), box.top + 1.0);
    } else {
      final box = boxes.last;
      _virtualDragPos = Offset(box.left + (box.width / 2.0), box.bottom - 1.0);
    }
  }

  void handleHandlePanUpdate(DragUpdateDetails details, bool isStartHandle) {
    if (_virtualDragPos == null ||
        _activeDragStart == null ||
        _activeDragEnd == null) return;

    final renderBox = getRenderParagraph();
    _virtualDragPos = _virtualDragPos! + details.delta;

    final double clampedX =
        _virtualDragPos!.dx.clamp(0.0, renderBox.size.width);
    final double clampedY = _virtualDragPos!.dy
        .clamp(0.0, math.max(0.0, renderBox.size.height - 0.1));

    final position = renderBox.getPositionForOffset(Offset(clampedX, clampedY));
    int newOffset = position.offset;

    // ENGINE DEAD-ZONE BUGFIX (Newline Handling)
    if (newOffset == 0 &&
        (_virtualDragPos!.dx > 20.0 || _virtualDragPos!.dy > 20.0)) {
      newOffset = isStartHandle ? _activeDragStart! : _activeDragEnd!;
    }

    int finalStart = _activeDragStart!;
    int finalEnd = _activeDragEnd!;

    if (isStartHandle) {
      finalStart = newOffset;
    } else {
      finalEnd = newOffset;
    }

    // THE FINAL FIX: Absolute Swap Instead of Compression
    if (finalStart > finalEnd) {
      final temp = finalStart;
      finalStart = finalEnd;
      finalEnd = temp;
    }

    // Update active state so it persists across frames
    _activeDragStart = finalStart;
    _activeDragEnd = finalEnd;

    onSelectionChanged(
        TextSelection(baseOffset: finalStart, extentOffset: finalEnd));
  }

  void handleHandlePanEnd([DragEndDetails? details]) {
    _virtualDragPos = null;
    _activeDragStart = null;
    _activeDragEnd = null;
  }

  void handleHandlePanCancel() {
    _virtualDragPos = null;
    _activeDragStart = null;
    _activeDragEnd = null;
  }
}
