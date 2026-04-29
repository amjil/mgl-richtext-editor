import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart' hide MongolRichText;

import 'm_rich_text.dart';
import 'm_render_paragraph.dart';
import 'm_selection_painter.dart';
import 'm_caret_painter.dart';
import 'line_divider_painter.dart';

import 'mgl_text_gesture_handler.dart';
import 'mgl_drag_handle.dart';

const double _kBlockLineHeight = 2.0;
const double _kCaretWidth = 2.0;

// 🌟 Added a visual correction constant to push the handle perfectly to the right edge.
const double _kHandleVisualShift = 3.0;

/// Ensures the TextSpan uses the proper line height required for Mongolian vertical layout.
TextSpan _ensureLineHeight(TextSpan span) {
  final baseStyle = span.style ?? const TextStyle();
  final mergedStyle = baseStyle.copyWith(
    height: _kBlockLineHeight,
    // Forces the extra line-height space to be distributed equally
    // to perfectly center the text inside its physical column box.
    leadingDistribution: TextLeadingDistribution.even,
  );

  if (span.children == null || span.children!.isEmpty) {
    return TextSpan(text: span.text, style: mergedStyle);
  }
  return TextSpan(
    style: mergedStyle,
    children: span.children!.map((InlineSpan c) {
      if (c is TextSpan) return _ensureLineHeight(c);
      return TextSpan(text: c.toPlainText(), style: mergedStyle);
    }).toList(),
  );
}

class MglSelectableText extends StatefulWidget {
  final TextSpan textSpan;
  final TextSelection? selection;
  final bool showCursor;
  final bool isFocused;
  final bool showLineDivider;

  final bool showCaretHandle;
  final bool showStartHandle;
  final bool showEndHandle;

  final ValueChanged<TextSelection>? onSelectionChanged;
  final GlobalKey textKey;

  const MglSelectableText({
    required this.textKey,
    required this.textSpan,
    this.selection,
    this.showCursor = false,
    this.isFocused = false,
    this.showLineDivider = true,
    this.showCaretHandle = false,
    this.showStartHandle = false,
    this.showEndHandle = false,
    this.onSelectionChanged,
    super.key,
  });

  /// Safely retrieves the Mongolian render object from the GlobalKey.
  static MongolRenderParagraph? _safeRenderParagraph(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final ro = ctx.findRenderObject();
      if (ro is MongolRenderParagraph) return ro;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Calculates text position based on global screen coordinates.
  static TextPosition getPositionAtOffset(GlobalKey key, Offset globalOffset) {
    final renderBox = _safeRenderParagraph(key);
    if (renderBox == null) return const TextPosition(offset: 0);
    final localOffset = renderBox.globalToLocal(globalOffset);
    return renderBox.getPositionForOffset(localOffset);
  }

  /// Calculates global offset for a specific character caret position.
  static Offset? getGlobalOffsetForCaret(GlobalKey key, int caretOffset) {
    final renderBox = _safeRenderParagraph(key);
    if (renderBox == null || !renderBox.hasSize) return null;
    final local = renderBox.getOffsetForCaret(
        TextPosition(offset: caretOffset), Rect.zero);
    return renderBox.localToGlobal(local);
  }

  @override
  State<MglSelectableText> createState() => _MglSelectableTextState();
}

class _MglSelectableTextState extends State<MglSelectableText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late MglTextGestureHandler _gestureHandler;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _handleOverlayEntry;

  int _tapCount = 0;
  Timer? _tapResetTimer;

  bool get _shouldBlink =>
      widget.isFocused &&
      widget.showCursor &&
      (widget.selection?.isCollapsed == true);

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
    _initGestureHandler();
  }

  void _initGestureHandler() {
    _gestureHandler = MglTextGestureHandler(
      getRenderParagraph: () {
        final rb = MglSelectableText._safeRenderParagraph(widget.textKey);
        if (rb == null) throw Exception("RenderBox not ready");
        return rb;
      },
      currentSelection: widget.selection,
      onSelectionChanged: widget.onSelectionChanged ?? (_) {},
    );
  }

  /// Handles touch down events to track double taps or range selection visibility.
  void _handlePointerDown(PointerDownEvent event) {
    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 300), () {
      _tapCount = 0;
    });

    if (_tapCount >= 2 ||
        (widget.selection != null && !widget.selection!.isCollapsed)) {
      _showHandle();
    }
  }

  /// Creates an OverlayEntry to host the draggable selection handles.
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(builder: (context) {
      final renderBox = MglSelectableText._safeRenderParagraph(widget.textKey);
      if (renderBox == null || widget.selection == null)
        return const SizedBox.shrink();

      List<Widget> handles = [];
      const double touchExtension = 48.0;

      // Mathematical centering metrics
      final double fontSize = widget.textSpan.style?.fontSize ?? 20.0;
      final double heightMultiplier =
          widget.textSpan.style?.height ?? _kBlockLineHeight;
      final double columnWidth = fontSize * heightMultiplier;
      final double paddingLeft = (columnWidth - fontSize) / 2.0;

      // 1. Handle Caret Placement (Single Handle)
      if (widget.showCaretHandle && widget.selection!.isCollapsed) {
        final int offset = widget.selection!.baseOffset;
        final caretOffsetLocal = renderBox.getOffsetForCaret(
            TextPosition(offset: offset), Rect.zero);

        // 🌟 Added visual shift to push the handle absolutely to the right side of the caret
        final double targetX = caretOffsetLocal.dx +
            paddingLeft +
            fontSize +
            _kCaretWidth +
            _kHandleVisualShift;

        final handlePos = Offset(
            targetX + touchExtension, caretOffsetLocal.dy + touchExtension);

        handles.add(MglDragHandle(
          key: const ValueKey('mgl_caret_handle'),
          center: handlePos,
          onPanUpdate: _gestureHandler.handleCaretPanUpdate,
        ));
      }

      // 2. Handle Range Selection (Start and End Handles)
      if (!widget.selection!.isCollapsed &&
          (widget.showStartHandle || widget.showEndHandle)) {
        final boxes = renderBox.getBoxesForSelection(widget.selection!);
        if (boxes.isNotEmpty) {
          if (widget.showStartHandle) {
            final firstBox = boxes.first;
            final double startX = firstBox.left +
                paddingLeft +
                fontSize +
                _kCaretWidth +
                _kHandleVisualShift;

            final startPos =
                Offset(startX + touchExtension, firstBox.top + touchExtension);
            handles.add(MglDragHandle(
              key: const ValueKey('mgl_start_handle'),
              center: startPos,
              onPanUpdate: (details) =>
                  _gestureHandler.handleHandlePanUpdate(details, true),
            ));
          }
          if (widget.showEndHandle) {
            final lastBox = boxes.last;
            final double endX = lastBox.left +
                paddingLeft +
                fontSize +
                _kCaretWidth +
                _kHandleVisualShift;

            final endPos =
                Offset(endX + touchExtension, lastBox.bottom + touchExtension);
            handles.add(MglDragHandle(
              key: const ValueKey('mgl_end_handle'),
              center: endPos,
              onPanUpdate: (details) =>
                  _gestureHandler.handleHandlePanUpdate(details, false),
            ));
          }
        }
      }

      if (handles.isEmpty) return const SizedBox.shrink();

      return CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(-touchExtension, -touchExtension),
        child: SizedBox(
          width: renderBox.size.width + (touchExtension * 2),
          height: renderBox.size.height + (touchExtension * 2),
          child: Stack(clipBehavior: Clip.none, children: handles),
        ),
      );
    });
  }

  /// Displays or refreshes the persistent handles overlay.
  void _showHandle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_handleOverlayEntry == null) {
        _handleOverlayEntry = _createOverlayEntry();
        Overlay.maybeOf(context)?.insert(_handleOverlayEntry!);
      } else {
        _handleOverlayEntry!.markNeedsBuild();
      }
    });
  }

  /// Removes the handles overlay from view.
  void _hideHandle() {
    if (_handleOverlayEntry != null) {
      _handleOverlayEntry!.remove();
      _handleOverlayEntry = null;
    }
  }

  @override
  void didUpdateWidget(covariant MglSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initGestureHandler();

    // 1. Handle Overlay lifecycle
    if (widget.textSpan != oldWidget.textSpan) {
      _hideHandle();
    } else if (widget.selection != oldWidget.selection) {
      if (widget.selection != null) _showHandle();
    } else if (_handleOverlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOverlayEntry?.markNeedsBuild();
      });
    }

    // 2. Accurately control caret blinking state
    final bool wasBlinking = oldWidget.isFocused &&
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
    _hideHandle();
    _tapResetTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MongolRenderParagraph? renderBox =
        MglSelectableText._safeRenderParagraph(widget.textKey);

    Widget content = MongolRichText(
      key: widget.textKey,
      text: _ensureLineHeight(widget.textSpan),
    );

    if (widget.showLineDivider) {
      content = CustomPaint(
        painter: LineDividerPainter(
          renderBox: renderBox,
          text: widget.textSpan.toPlainText(),
          extendToLineEnd: true,
        ),
        child: content,
      );
    }

    if (widget.selection != null && !widget.selection!.isCollapsed) {
      content = CustomPaint(
        painter: MongolSelectionPainter(
          textKey: widget.textKey,
          selection: widget.selection!,
          hasFocus: widget.isFocused,
        ),
        child: content,
      );
    }

    if (widget.selection?.isCollapsed == true && widget.showCursor) {
      content = CustomPaint(
        foregroundPainter: MongolCaretPainter(
          textKey: widget.textKey,
          selection: widget.selection!,
          caretColor: Theme.of(context).colorScheme.onSurface,
          blinkAnimation: _shouldBlink ? _blinkController : null,
        ),
        child: content,
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: RepaintBoundary(child: content),
        ),
      ),
    );
  }
}
