import 'dart:ui' as ui show Gradient, Shader;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mongol/src/base/mongol_text_align.dart';
import 'package:mongol/src/base/mongol_text_painter.dart';

const String _kEllipsis = '\u2026';

class MongolRenderParagraph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TextParentData>,
        RenderInlineChildrenContainerDefaults,
        RelayoutWhenSystemFontsChangeMixin {
  MongolRenderParagraph(
    TextSpan text, {
    MongolTextAlign textAlign = MongolTextAlign.top,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
    double textScaleFactor = 1.0,
    int? maxLines,
  })  : assert(maxLines == null || maxLines > 0),
        _softWrap = softWrap,
        _overflow = overflow,
        _textPainter = MongolTextPainter(
          text: text,
          textAlign: textAlign,
          textScaleFactor: textScaleFactor,
          maxLines: maxLines,
          ellipsis: overflow == TextOverflow.ellipsis ? _kEllipsis : null,
        );

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TextParentData) {
      child.parentData = TextParentData();
    }
  }

  final MongolTextPainter _textPainter;
  MongolTextPainter get textPainter => _textPainter;

  TextSpan get text => _textPainter.text!;
  set text(TextSpan value) {
    switch (_textPainter.text!.compareTo(value)) {
      case RenderComparison.identical:
      case RenderComparison.metadata:
        return;
      case RenderComparison.paint:
        _textPainter.text = value;
        markNeedsPaint();
        break;
      case RenderComparison.layout:
        _textPainter.text = value;
        markNeedsLayout();
        break;
    }
  }

  MongolTextAlign get textAlign => _textPainter.textAlign;
  set textAlign(MongolTextAlign value) {
    if (_textPainter.textAlign == value) {
      return;
    }
    _textPainter.textAlign = value;
    markNeedsPaint();
  }

  bool get softWrap => _softWrap;
  bool _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) {
      return;
    }
    _softWrap = value;
    markNeedsLayout();
  }

  TextOverflow get overflow => _overflow;
  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) {
      return;
    }
    _overflow = value;
    _textPainter.ellipsis = value == TextOverflow.ellipsis ? _kEllipsis : null;
    markNeedsLayout();
  }

  double get textScaleFactor => _textPainter.textScaleFactor;
  set textScaleFactor(double value) {
    if (_textPainter.textScaleFactor == value) return;
    _textPainter.textScaleFactor = value;
    markNeedsLayout();
  }

  int? get maxLines => _textPainter.maxLines;
  set maxLines(int? value) {
    assert(value == null || value > 0);
    if (_textPainter.maxLines == value) {
      return;
    }
    _textPainter.maxLines = value;
    _overflowShader = null;
    markNeedsLayout();
  }

  bool _needsClipping = false;
  ui.Shader? _overflowShader;

  @visibleForTesting
  bool get debugHasOverflowShader => _overflowShader != null;

  void _layoutText({
    double minHeight = 0.0,
    double maxHeight = double.infinity,
  }) {
    final heightMatters = softWrap || overflow == TextOverflow.ellipsis;
    _textPainter.layout(
      minHeight: minHeight,
      maxHeight: heightMatters ? maxHeight : double.infinity,
    );
  }

  void _layoutTextWithConstraints(BoxConstraints constraints) {
    _layoutText(
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText();
    return _textPainter.minIntrinsicHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _layoutText();
    return _textPainter.maxIntrinsicHeight;
  }

  double _computeIntrinsicWidth(double height) {
    _layoutText(minHeight: height, maxHeight: height);
    return _textPainter.width;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _computeIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _computeIntrinsicWidth(height);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    assert(constraints.debugAssertIsValid());
    _layoutTextWithConstraints(constraints);
    return _textPainter.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    if (event is! PointerDownEvent) return;
    _layoutTextWithConstraints(constraints);
    final offset = entry.localPosition;
    final position = _textPainter.getPositionForOffset(offset);
    final span = _textPainter.text!.getSpanForPosition(position);
    if (span == null) {
      return;
    }
    if (span is TextSpan) {
      span.recognizer?.addPointer(event);
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    _layoutTextWithConstraints(constraints);
    final textSize = _textPainter.size;
    final textDidExceedMaxLines = _textPainter.didExceedMaxLines;
    size = constraints.constrain(textSize);

    final didOverflowWidth =
        size.width < textSize.width || textDidExceedMaxLines;
    final didOverflowHeight = size.height < textSize.height;
    final hasVisualOverflow = didOverflowHeight || didOverflowWidth;
    if (hasVisualOverflow) {
      switch (_overflow) {
        case TextOverflow.visible:
          _needsClipping = false;
          _overflowShader = null;
          break;
        case TextOverflow.clip:
        case TextOverflow.ellipsis:
          _needsClipping = true;
          _overflowShader = null;
          break;
        case TextOverflow.fade:
          _needsClipping = true;
          final fadeSizePainter = MongolTextPainter(
            text: TextSpan(style: _textPainter.text!.style, text: '\u2026'),
            textScaleFactor: textScaleFactor,
          )..layout();
          if (didOverflowWidth) {
            double fadeEnd, fadeStart;
            fadeEnd = size.height;
            fadeStart = fadeEnd - fadeSizePainter.height;
            _overflowShader = ui.Gradient.linear(
              Offset(0.0, fadeStart),
              Offset(0.0, fadeEnd),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          } else {
            final fadeEnd = size.width;
            final fadeStart = fadeEnd - fadeSizePainter.width / 2.0;
            _overflowShader = ui.Gradient.linear(
              Offset(fadeStart, 0.0),
              Offset(fadeEnd, 0.0),
              <Color>[const Color(0xFFFFFFFF), const Color(0x00FFFFFF)],
            );
          }
          break;
      }
    } else {
      _needsClipping = false;
      _overflowShader = null;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _layoutTextWithConstraints(constraints);
    if (_needsClipping) {
      final bounds = offset & size;
      if (_overflowShader != null) {
        context.canvas.saveLayer(bounds, Paint());
      } else {
        context.canvas.save();
      }
      context.canvas.clipRect(bounds);
    }

    _textPainter.paint(context.canvas, offset);

    if (_needsClipping) {
      if (_overflowShader != null) {
        context.canvas.translate(offset.dx, offset.dy);
        final paint = Paint()
          ..blendMode = BlendMode.modulate
          ..shader = _overflowShader;
        context.canvas.drawRect(Offset.zero & size, paint);
      }
      context.canvas.restore();
    }
  }

  double? getFullHeightForCaret(TextPosition position) {
    return textPainter.getFullWidthForCaret(
        position, Rect.fromLTRB(0, 0, 0, 0));
  }

  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    return textPainter.getOffsetForCaret(position, caretPrototype);
  }

  TextRange getWordBoundary(TextPosition position) {
    return textPainter.getWordBoundary(position);
  }

  List<Rect> getBoxesForSelection(TextSelection selection) {
    return textPainter.getBoxesForSelection(selection);
  }

  TextPosition getPositionForOffset(Offset offset) {
    return textPainter.getPositionForOffset(offset);
  }
}
