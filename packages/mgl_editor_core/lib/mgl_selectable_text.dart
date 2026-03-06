import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart' hide MongolRichText;

// Base rendering and custom painters
import 'm_rich_text.dart';
import 'm_render_paragraph.dart';
import 'm_selection_painter.dart';
import 'm_caret_painter.dart';
import 'line_divider_painter.dart';

/// Line height multiplier: gap between lines (columns) within a block. Larger = more spacing; 2.0 is noticeably wider.
const double _kBlockLineHeight = 2.0;

/// Ensures [span] and its children use TextStyle with [height] for Mongol vertical layout.
/// MongolRenderParagraph only supports TextSpan (no WidgetSpan/other InlineSpan); non-TextSpan
/// children are flattened to plain TextSpan so layout does not break.
TextSpan _ensureLineHeight(TextSpan span) {
  final baseStyle = span.style ?? const TextStyle();
  final mergedStyle = baseStyle.copyWith(height: _kBlockLineHeight);
  if (span.children == null || span.children!.isEmpty) {
    return TextSpan(text: span.text, style: mergedStyle);
  }
  return TextSpan(
    style: mergedStyle,
    children: span.children!.map((InlineSpan c) {
      if (c is TextSpan) return _ensureLineHeight(c);
      // Mongol does not support InlineSpan other than TextSpan; flatten to plain text.
      return TextSpan(text: c.toPlainText(), style: mergedStyle);
    }).toList(),
  );
}

/// Minimal Mongol block rendering atom. Stateless, no focus or gesture handling; selection, caret, dividers are driven by props.
/// Pass only a [TextSpan] tree (no [WidgetSpan] / other [InlineSpan]) — MongolRenderParagraph does not support them.
class MglSelectableText extends StatefulWidget {
  final TextSpan textSpan;
  final TextSelection? selection;
  
  /// Whether to show the blinking caret. Driven by ClojureDart timer or state.
  final bool showCursor;
  
  /// Whether this block is active/focused (affects selection color etc.).
  final bool isFocused;
  
  final bool showLineDivider;
  
  /// Key required so Clojure side can call static helpers for coordinate conversion.
  final GlobalKey textKey;

  const MglSelectableText({
    required this.textKey,
    required this.textSpan,
    this.selection,
    this.showCursor = false,
    this.isFocused = false,
    this.showLineDivider = true,
    super.key,
  });

  static MongolRenderParagraph? _safeRenderParagraph(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final ro = ctx.findRenderObject();
      if (ro is MongolRenderParagraph) return ro;
      return null;
    } catch (_) {
      // GlobalKey may briefly point to inactive element during rebuild; findRenderObject can fail
      return null;
    }
  }

  /// Static helper: convert global offset to character offset in text. Used by ClojureDart gesture handler.
  static TextPosition getPositionAtOffset(GlobalKey key, Offset globalOffset) {
    final renderBox = _safeRenderParagraph(key);
    if (renderBox == null) return const TextPosition(offset: 0);
    final localOffset = renderBox.globalToLocal(globalOffset);
    return renderBox.getPositionForOffset(localOffset);
  }

  @override
  State<MglSelectableText> createState() => _MglSelectableTextState();
}

class _MglSelectableTextState extends State<MglSelectableText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;

  bool get _shouldBlink =>
      widget.isFocused && widget.showCursor && (widget.selection?.isCollapsed == true);

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (_shouldBlink) {
      _blinkController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MglSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBlinking = oldWidget.isFocused &&
        oldWidget.showCursor &&
        (oldWidget.selection?.isCollapsed == true);
    if (_shouldBlink && !wasBlinking) {
      _blinkController
        ..value = 0.0
        ..repeat();
    } else if (!_shouldBlink && wasBlinking) {
      _blinkController.stop();
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MongolRenderParagraph? renderBox =
        MglSelectableText._safeRenderParagraph(widget.textKey);

    return IntrinsicWidth(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Base text (line height applied for block line/column spacing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: MongolRichText(
              key: widget.textKey,
              text: _ensureLineHeight(widget.textSpan),
            ),
          ),

          // 2. Vertical line dividers
          if (widget.showLineDivider)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: LineDividerPainter(
                    renderBox: renderBox,
                    text: widget.textSpan.toPlainText(),
                    extendToLineEnd: true,
                  ),
                ),
              ),
            ),

          // 3. Selection background
          if (widget.selection != null && !widget.selection!.isCollapsed)
            CustomPaint(
              painter: MongolSelectionPainter(
                textKey: widget.textKey,
                selection: widget.selection!,
                hasFocus: widget.isFocused,
              ),
            ),

          // 4. Caret (driven by showCursor, no internal AnimationController)
          // Use onSurface so cursor is visible in both light and dark themes (contrasts with surface).
          if (widget.selection?.isCollapsed == true && widget.showCursor)
            CustomPaint(
              painter: MongolCaretPainter(
                textKey: widget.textKey,
                selection: widget.selection!,
                caretColor: Theme.of(context).colorScheme.onSurface,
                blinkAnimation: _shouldBlink ? _blinkController : null,
              ),
            ),
        ],
      ),
    );
  }
}