import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'm_render_paragraph.dart';
import 'package:mongol/src/base/mongol_text_align.dart';

class MongolRichText extends LeafRenderObjectWidget {
  const MongolRichText({
    Key? key,
    required this.text,
    this.textAlign = MongolTextAlign.top,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaleFactor = 1.0,
    this.maxLines,
  })  : assert(maxLines == null || maxLines > 0),
        super(key: key);

  final TextSpan text;
  final MongolTextAlign textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final double textScaleFactor;
  final int? maxLines;

  @override
  MongolRenderParagraph createRenderObject(BuildContext context) {
    return MongolRenderParagraph(
      text,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, MongolRenderParagraph renderObject) {
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaleFactor = textScaleFactor
      ..maxLines = maxLines;
  }
}

