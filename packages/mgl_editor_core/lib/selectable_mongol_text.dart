import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'm_rich_text.dart';
import 'm_render_paragraph.dart';

typedef SelectableRegistrationCallback = void Function(
    RenderBox renderBox, dynamic selectable);

class MglSelectableText extends StatefulWidget {
  final TextSpan textSpan;
  final dynamic gestureRecognizers;
  final TextSelection? selection;
  final TextStyle? style;
  final FocusNode? focusNode;
  final SelectableRegistrationCallback? onMounted;
  final VoidCallback? onUnmounted;
  final ValueChanged<TextSelection>? onSelectionChanged;

  const MglSelectableText({
    super.key,
    required this.textSpan,
    this.gestureRecognizers,
    this.selection,
    this.onSelectionChanged,
    this.style,
    this.focusNode,
    this.onMounted,
    this.onUnmounted,
  });

  @override
  State<MglSelectableText> createState() => MglSelectableTextState();
}

class MglSelectableTextState extends State<MglSelectableText>
    with SingleTickerProviderStateMixin {
  final GlobalKey _textKey = GlobalKey();
  late FocusNode _focusNode;
  late AnimationController _caretController;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _caretController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _focusNode.addListener(_onFocusChange);

    // If there is a collapsed selection at initialization, it usually means this is newly created or selected.
    if (widget.selection != null && widget.selection!.isCollapsed) {
      _focusNode.requestFocus();
    }

    if (_focusNode.hasFocus) {
      _caretController.value = 1.0;
      _caretController.repeat(reverse: true);
    }

    _register();
  }

  void _register() {
    if (widget.onMounted != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final renderBox =
            _textKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox is MongolRenderParagraph) {
          widget.onMounted!(renderBox, renderBox);
        }
      });
    }
  }

  void _disposeRecognizers(dynamic recognizers) {
    if (recognizers != null && recognizers is Iterable) {
      for (final recognizer in recognizers) {
        if (recognizer is GestureRecognizer) {
          recognizer.dispose();
        }
      }
    }
  }

  @override
  void didUpdateWidget(MglSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }

    // If recognizers changed, dispose old ones
    if (widget.gestureRecognizers != oldWidget.gestureRecognizers) {
      _disposeRecognizers(oldWidget.gestureRecognizers);
    }

    // Smart focus logic:
    // If selection changes from none to some, or from non-focused state to collapsed selection
    if (widget.selection != null &&
        widget.selection!.isCollapsed &&
        (oldWidget.selection == null || !oldWidget.selection!.isCollapsed) &&
        !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    _register();
  }

  @override
  void dispose() {
    _disposeRecognizers(widget.gestureRecognizers);
    widget.onUnmounted?.call();
    _caretController.dispose();
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      if (_focusNode.hasFocus) {
        _caretController.value = 1.0;
        _caretController.repeat(reverse: true);
      } else {
        _caretController.stop();
        _caretController.value = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                bottom: 20.0), // Added padding for cursor visibility
            child: MongolRichText(
              key: _textKey,
              text: widget.textSpan,
            ),
          ),
          if (widget.selection != null &&
              widget.selection!.isCollapsed &&
              _focusNode.hasFocus)
            AnimatedBuilder(
              animation: _caretController,
              builder: (context, child) {
                final opacity = _caretController.value > 0.5 ? 1.0 : 0.0;
                return Opacity(
                  opacity: opacity,
                  child: CustomPaint(
                    painter: _MongolCaretPainter(
                      textKey: _textKey,
                      selection: widget.selection!,
                    ),
                  ),
                );
              },
            ),
          if (widget.selection != null && !widget.selection!.isCollapsed)
            CustomPaint(
              painter: _MongolSelectionPainter(
                textKey: _textKey,
                selection: widget.selection!,
              ),
            ),
        ],
      ),
    );
  }
}

class _MongolCaretPainter extends CustomPainter {
  final GlobalKey textKey;
  final TextSelection selection;

  _MongolCaretPainter({required this.textKey, required this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    final renderBox =
        textKey.currentContext?.findRenderObject() as MongolRenderParagraph?;
    if (renderBox == null) return;

    final pos = TextPosition(offset: selection.baseOffset);
    final offset = renderBox.getOffsetForCaret(pos, Rect.zero);
    final caretWidth = renderBox.getFullHeightForCaret(pos) ?? 20.0;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, caretWidth, 2.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MongolCaretPainter oldDelegate) =>
      oldDelegate.selection != selection;
}

class _MongolSelectionPainter extends CustomPainter {
  final GlobalKey textKey;
  final TextSelection selection;

  _MongolSelectionPainter({required this.textKey, required this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    final renderBox =
        textKey.currentContext?.findRenderObject() as MongolRenderParagraph?;
    if (renderBox == null) return;

    final boxes = renderBox.getBoxesForSelection(selection);
    final paint = Paint()..color = Colors.blue.withOpacity(0.3);

    for (final box in boxes) {
      canvas.drawRect(box, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MongolSelectionPainter oldDelegate) =>
      oldDelegate.selection != selection;
}
