import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'm_render_paragraph.dart';

/// CustomPainter that draws dashed lines in the middle of each text line
class LineDividerPainter extends CustomPainter {
  final GlobalKey textKey;
  final String? text;
  /// If true, lines extend to the full height of the canvas/line, ignoring text height
  final bool extendToLineEnd;

  LineDividerPainter({
    required this.textKey,
    this.text,
    this.extendToLineEnd = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final renderBox =
        textKey.currentContext?.findRenderObject() as MongolRenderParagraph?;
    
    if (renderBox == null) {
      return;
    }
    
    if (!renderBox.hasSize) {
      return;
    }
    
    if (!renderBox.attached) {
      return;
    }
    
    // In a Stack, both renderBox and CustomPaint are direct children,
    // so their coordinate systems should be the same (both relative to Stack's origin)
    // But renderBox might have padding or other offsets, so we need to find its position
    Offset renderBoxOffset = Offset.zero;
    try {
      // Try to get renderBox's position relative to Stack
      // If renderBox is not positioned, it should be at (0,0)
      final renderBoxContext = textKey.currentContext;
      if (renderBoxContext != null) {
        // Find the Stack ancestor
        final stackRenderObject = renderBoxContext.findAncestorRenderObjectOfType<RenderStack>();
        if (stackRenderObject != null) {
          // Get global positions
          final renderBoxGlobalPos = renderBox.localToGlobal(Offset.zero);
          final stackGlobalPos = stackRenderObject.localToGlobal(Offset.zero);
          renderBoxOffset = renderBoxGlobalPos - stackGlobalPos;
        }
      }
    } catch (e) {
      renderBoxOffset = Offset.zero;
    }

    try {
      // Get the text content and style information
      final text = renderBox.textPainter.text?.toPlainText() ?? '';
      
      if (text.isEmpty) {
        return;
      }

      final textLength = text.length;

      // Optimized: Collect line ranges efficiently by jumping to next line start
      // Instead of checking every character (O(n)), we only check each line (O(lines))
      // This reduces complexity from O(n) to O(lines) where n is character count
      final lineRanges = <TextRange>[];
      final visitedRanges = <int, int>{}; // Map of start -> end to avoid duplicates
      
      int currentOffset = 0;
      while (currentOffset < textLength) {
        // Get line boundary for current position
        final lineRange = renderBox.getLineBoundary(TextPosition(offset: currentOffset));
        
        // Check if we've already seen this line
        if (!visitedRanges.containsKey(lineRange.start)) {
          visitedRanges[lineRange.start] = lineRange.end;
          lineRanges.add(lineRange);
        }
        
        // Jump to the start of next line (or end of text if this is the last line)
        if (lineRange.end >= textLength) {
          break; // Reached end of text
        }
        currentOffset = lineRange.end;
      }

      // Draw dashed line in the middle of each line
      // Use a subtle gray color that doesn't overlap with text
      final paint = Paint()
        ..color = Colors.grey.withOpacity(0.5)  // Use subtle gray
        ..strokeWidth = 1.0  // Thinner line
        ..style = PaintingStyle.stroke;

      // Sort line ranges by start position for easier access to next line
      final sortedLineRanges = lineRanges..sort((a, b) => a.start.compareTo(b.start));
      
      for (int rangeIndex = 0; rangeIndex < sortedLineRanges.length; rangeIndex++) {
        final lineRange = sortedLineRanges[rangeIndex];
        
        // Get selection boxes for this line
        final selection = TextSelection(
          baseOffset: lineRange.start,
          extentOffset: lineRange.end,
        );
        final boxes = renderBox.getBoxesForSelection(selection);
        
        if (boxes.isEmpty) {
          continue;
        }

        // For vertical Mongol text:
        // - left/right represent horizontal position (X axis, left to right) - left and right boundaries of the line
        // - top/bottom represent vertical position (Y axis, top to bottom) - top and bottom boundaries of the line
        // Each line is vertical (arranged top to bottom) and lines are arranged horizontally (left to right)
        double minY = double.infinity;  // Vertical start (top)
        double maxY = 0.0;              // Vertical end (bottom)
        double maxRight = 0.0;          // Horizontal right edge (X axis, rightmost)
        double minLeft = double.infinity; // Horizontal left edge (X axis, leftmost)

        for (int i = 0; i < boxes.length; i++) {
          final box = boxes[i];
          // Convert box coordinates from renderBox local to CustomPaint local
          final boxLeft = box.left + renderBoxOffset.dx;   // Horizontal position (X)
          final boxTop = box.top + renderBoxOffset.dy;     // Vertical position (Y)
          final boxRight = box.right + renderBoxOffset.dx; // Horizontal position (X)
          final boxBottom = box.bottom + renderBoxOffset.dy; // Vertical position (Y)
          
          // For vertical text: left/right are X coordinates (horizontal), top/bottom are Y coordinates (vertical)
          minY = minY < boxTop ? minY : boxTop;      // Topmost vertical position
          maxY = maxY > boxBottom ? maxY : boxBottom;    // Bottommost vertical position
          maxRight = maxRight > boxRight ? maxRight : boxRight;  // Rightmost horizontal position
          minLeft = minLeft < boxLeft ? minLeft : boxLeft;           // Leftmost horizontal position
        }

        // Get next line's left edge (horizontal position) to calculate the middle position
        double nextLineLeft = double.infinity;
        if (rangeIndex < sortedLineRanges.length - 1) {
          final nextLineRange = sortedLineRanges[rangeIndex + 1];
          final nextSelection = TextSelection(
            baseOffset: nextLineRange.start,
            extentOffset: nextLineRange.end,
          );
          final nextBoxes = renderBox.getBoxesForSelection(nextSelection);
          if (nextBoxes.isNotEmpty) {
            double nextMinLeft = double.infinity;
            for (final box in nextBoxes) {
              // For vertical text, left is the horizontal left edge
              final boxLeft = box.left + renderBoxOffset.dx;
              nextMinLeft = nextMinLeft < boxLeft ? nextMinLeft : boxLeft;
            }
            nextLineLeft = nextMinLeft;
          }
        }

        // Check if this line is at least partially visible in the canvas
        // Skip lines that are completely outside the visible area
        // maxRight/minLeft are X coordinates (horizontal)
        if (maxRight < 0 || minLeft > size.width) {
          continue;
        }
        
        // Check if Y coordinates are valid (at least partially visible)
        // minY/maxY are Y coordinates (vertical)
        if (maxY < 0 || minY > size.height) {
          continue;
        }
        
        // Draw the line at the right edge of each column
        // For vertical Mongol text, each "line" is actually a vertical column
        // The line should be drawn at the right edge (100%) of the current column
        // This creates a divider line between columns
        double lineX;
        // Calculate the right edge of the current column
        double lineWidth = maxRight - minLeft;
        // Draw at the right edge (100%) of the column
        lineX = minLeft + lineWidth * 1.0; // Draw at right edge (100%)
        
        // Skip drawing if lineX is completely outside canvas bounds
        if (lineX < 0 || lineX > size.width) {
          continue;
        }
        
        // minY/maxY are Y coordinates (vertical positions)
        // If extendToLineEnd is true, draw from top to bottom of canvas, ignoring text height
        final startY = extendToLineEnd ? 0.0 : minY.clamp(0.0, size.height);
        final endY = extendToLineEnd ? size.height : maxY.clamp(0.0, size.height);

        // Draw vertical dashed line in the middle of the line
        // (vertical because Mongol text lines are vertical, arranged horizontally)
        // At this point, we know lineX is within bounds and startY/endY are clamped
        final dashLength = 5.0;
        final dashSpace = 3.0;

        double currentY = startY;
        while (currentY < endY) {
          final dashEnd = (currentY + dashLength < endY) 
              ? currentY + dashLength 
              : endY;
          
          // Draw the dash (coordinates are already validated and clamped)
          if (dashEnd > currentY) {
            canvas.drawLine(
              Offset(lineX, currentY),
              Offset(lineX, dashEnd),
              paint,
            );
          }
          currentY += dashLength + dashSpace;
        }
      }
    } catch (e, stackTrace) {
      // Silently handle errors
    }
  }

  @override
  bool shouldRepaint(covariant LineDividerPainter oldDelegate) {
    // Repaint when the text key, text content, or extendToLineEnd changes
    return oldDelegate.textKey != textKey || 
           oldDelegate.text != text || 
           oldDelegate.extendToLineEnd != extendToLineEnd;
  }
}
