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
import 'mgl_text_selection_toolbar.dart';

const double _kBlockLineHeight = 2.0;
const double _kCaretWidth = 2.0;
const double _kHandleVisualShift = 3.0;

TextSpan _ensureLineHeight(TextSpan span) {
  final baseStyle = span.style ?? const TextStyle();
  final mergedStyle = baseStyle.copyWith(
    height: _kBlockLineHeight,
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

  /// Mobile-only: show the Mongolian paste/copy/select-all/cut menu.
  final bool showToolbar;
  final VoidCallback? onPaste;
  final VoidCallback? onCopy;
  final VoidCallback? onSelectAll;
  final VoidCallback? onCut;

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
    this.showToolbar = false,
    this.onPaste,
    this.onCopy,
    this.onSelectAll,
    this.onCut,
    this.onSelectionChanged,
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
      return null;
    }
  }

  static TextPosition getPositionAtOffset(GlobalKey key, Offset globalOffset) {
    final renderBox = _safeRenderParagraph(key);
    if (renderBox == null) return const TextPosition(offset: 0);
    final localOffset = renderBox.globalToLocal(globalOffset);
    return renderBox.getPositionForOffset(localOffset);
  }

  /// True when the text span under [globalOffset] has a gesture recognizer
  /// (e.g. wiki link / tag). Callers can skip focus/selection tap handling.
  static bool hasRecognizerAt(GlobalKey key, Offset globalOffset) {
    final renderBox = _safeRenderParagraph(key);
    if (renderBox == null) return false;
    try {
      final localOffset = renderBox.globalToLocal(globalOffset);
      final position = renderBox.getPositionForOffset(localOffset);
      final span = renderBox.textPainter.text?.getSpanForPosition(position);
      return span is TextSpan && span.recognizer != null;
    } catch (_) {
      return false;
    }
  }

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
  OverlayEntry? _toolbarOverlayEntry;

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
    if (widget.showToolbar) {
      _showToolbar();
    }
  }

  void _initGestureHandler() {
    _gestureHandler = MglTextGestureHandler(
      getRenderParagraph: () =>
          MglSelectableText._safeRenderParagraph(widget.textKey),
      getSelection: () => widget.selection,
      onSelectionChanged: widget.onSelectionChanged ?? (_) {},
    );
  }

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

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(builder: (context) {
      final renderBox = MglSelectableText._safeRenderParagraph(widget.textKey);
      if (renderBox == null || widget.selection == null)
        return const SizedBox.shrink();

      List<Widget> handles = [];
      const double touchExtension = 48.0;

      final double fontSize = widget.textSpan.style?.fontSize ?? 20.0;
      final double heightMultiplier =
          widget.textSpan.style?.height ?? _kBlockLineHeight;
      final double columnWidth = fontSize * heightMultiplier;
      final double paddingLeft = (columnWidth - fontSize) / 2.0;

      if (widget.showCaretHandle && widget.selection!.isCollapsed) {
        final int offset = widget.selection!.baseOffset;
        final caretOffsetLocal = renderBox.getOffsetForCaret(
            TextPosition(offset: offset), Rect.zero);

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
          onPanStart: _gestureHandler.handleCaretPanStart,
          onPanUpdate: _gestureHandler.handleCaretPanUpdate,
          onPanEnd: _gestureHandler.handleHandlePanEnd,
          onPanCancel: _gestureHandler.handleHandlePanCancel,
        ));
      }

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
              onPanStart: (details) =>
                  _gestureHandler.handleHandlePanStart(details, true),
              onPanUpdate: (details) =>
                  _gestureHandler.handleHandlePanUpdate(details, true),
              onPanEnd: _gestureHandler.handleHandlePanEnd,
              onPanCancel: _gestureHandler.handleHandlePanCancel,
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
              onPanStart: (details) =>
                  _gestureHandler.handleHandlePanStart(details, false),
              onPanUpdate: (details) =>
                  _gestureHandler.handleHandlePanUpdate(details, false),
              onPanEnd: _gestureHandler.handleHandlePanEnd,
              onPanCancel: _gestureHandler.handleHandlePanCancel,
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

  void _hideHandle() {
    if (_handleOverlayEntry != null) {
      _handleOverlayEntry!.remove();
      _handleOverlayEntry = null;
    }
  }

  OverlayEntry _createToolbarOverlay() {
    return OverlayEntry(builder: (context) {
      if (!widget.showToolbar ||
          widget.selection == null ||
          widget.selection!.isCollapsed) {
        return const SizedBox.shrink();
      }

      Offset offset = const Offset(12, 0);
      final double textSize = widget.textSpan.style?.fontSize ?? 20.0;
      final double menuFontSize = (textSize * 0.5).clamp(9.0, 11.0);
      final renderBox = MglSelectableText._safeRenderParagraph(widget.textKey);
      if (renderBox != null) {
        final boxes = renderBox.getBoxesForSelection(widget.selection!);
        if (boxes.isNotEmpty) {
          final box = boxes.first;
          offset = Offset(box.right + 8.0, box.top);
        }
      }

      return MglTextSelectionToolbar(
        layerLink: _layerLink,
        offset: offset,
        fontSize: menuFontSize,
        onPaste: () => _runToolbarAction(widget.onPaste),
        onCopy: () => _runToolbarAction(widget.onCopy),
        onSelectAll: () => _runToolbarAction(widget.onSelectAll),
        onCut: () => _runToolbarAction(widget.onCut),
      );
    });
  }

  void _showToolbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.showToolbar) {
        _hideToolbar();
        return;
      }
      if (_toolbarOverlayEntry == null) {
        _toolbarOverlayEntry = _createToolbarOverlay();
        Overlay.maybeOf(context)?.insert(_toolbarOverlayEntry!);
      } else {
        _toolbarOverlayEntry!.markNeedsBuild();
      }
    });
  }

  void _hideToolbar() {
    if (_toolbarOverlayEntry != null) {
      _toolbarOverlayEntry!.remove();
      _toolbarOverlayEntry = null;
    }
  }

  void _runToolbarAction(VoidCallback? action) {
    // Finish the overlay tap before mutating editor state / removing this overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action?.call();
    });
  }

  @override
  void didUpdateWidget(covariant MglSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.textSpan != oldWidget.textSpan) {
      _hideHandle();
    } else if (widget.selection != oldWidget.selection) {
      if (widget.selection != null) _showHandle();
    } else if (_handleOverlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleOverlayEntry?.markNeedsBuild();
      });
    }

    if (widget.showToolbar) {
      _showToolbar();
    } else {
      _hideToolbar();
    }

    _gestureHandler.onSelectionChanged = widget.onSelectionChanged ?? (_) {};

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
    _hideToolbar();
    _hideHandle();
    _tapResetTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the GlobalKey text widget as a stable Stack sibling instead of
    // nesting it inside CustomPaint. Nesting caused RenderCustomPaint to be
    // mutated during SliverList.performLayout when elements were retaken.
    final Widget text = MongolRichText(
      key: widget.textKey,
      text: _ensureLineHeight(widget.textSpan),
    );

    final List<Widget> overlays = [];

    if (widget.showLineDivider) {
      overlays.add(
        Positioned.fill(
          child: CustomPaint(
            painter: LineDividerPainter(
              textKey: widget.textKey,
              text: widget.textSpan.toPlainText(),
              extendToLineEnd: true,
            ),
          ),
        ),
      );
    }

    if (widget.selection != null && !widget.selection!.isCollapsed) {
      overlays.add(
        Positioned.fill(
          child: CustomPaint(
            painter: MongolSelectionPainter(
              textKey: widget.textKey,
              selection: widget.selection!,
              hasFocus: widget.isFocused,
            ),
          ),
        ),
      );
    }

    if (widget.selection?.isCollapsed == true && widget.showCursor) {
      overlays.add(
        Positioned.fill(
          child: CustomPaint(
            foregroundPainter: MongolCaretPainter(
              textKey: widget.textKey,
              selection: widget.selection!,
              caretColor: Theme.of(context).colorScheme.onSurface,
              blinkAnimation: _shouldBlink ? _blinkController : null,
            ),
          ),
        ),
      );
    }

    final Widget body = overlays.isEmpty
        ? text
        : Stack(
            clipBehavior: Clip.none,
            children: [text, ...overlays],
          );

    final double fontSize = widget.textSpan.style?.fontSize ?? 20.0;
    final double heightMultiplier =
        widget.textSpan.style?.height ?? _kBlockLineHeight;
    final double minColumn = fontSize * heightMultiplier;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minColumn, minHeight: fontSize),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: CompositedTransformTarget(
            link: _layerLink,
            child: RepaintBoundary(child: body),
          ),
        ),
      ),
    );
  }
}
