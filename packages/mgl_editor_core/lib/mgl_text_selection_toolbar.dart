import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart';

class MglTextSelectionToolbar extends StatelessWidget {
  final LayerLink layerLink;
  final Offset offset;
  final double fontSize;
  final VoidCallback onPaste;
  final VoidCallback onCopy;
  final VoidCallback onSelectAll;
  final VoidCallback onCut;

  const MglTextSelectionToolbar({
    super.key,
    required this.layerLink,
    this.offset = const Offset(12, 0),
    this.fontSize = 10.0,
    required this.onPaste,
    required this.onCopy,
    required this.onSelectAll,
    required this.onCut,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 16.0;
    const double padH = 8.0;
    const double padV = 6.0;

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      offset: offset,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.92 + (0.08 * value),
              alignment: Alignment.topLeft,
              child: child,
            ),
          );
        },
        // Follower fills the overlay; pin a content-sized bar so it does not
        // stretch to the bottom/right of the screen.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                color: const Color(0xFF2C2C2C),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMenuItem(
                          Icons.paste, 'ᠨᠠᠭᠠᠬᠤ', onPaste, iconSize, padH, padV),
                      _buildDivider(),
                      _buildMenuItem(
                          Icons.copy, 'ᠬᠠᠭᠤᠯᠬᠤ', onCopy, iconSize, padH, padV),
                      _buildDivider(),
                      _buildMenuItem(Icons.select_all, 'ᠪᠦᠭᠦᠳᠡ', onSelectAll,
                          iconSize, padH, padV),
                      _buildDivider(),
                      _buildMenuItem(Icons.content_cut, 'ᠬᠠᠢᠴᠢᠯᠠᠬᠤ', onCut,
                          iconSize, padH, padV),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap,
      double iconSize, double padH, double padV) {
    return InkWell(
      onTap: onTap,
      canRequestFocus: false,
      splashColor: Colors.white.withOpacity(0.12),
      highlightColor: Colors.white.withOpacity(0.08),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: Colors.white),
            const SizedBox(height: 4),
            MongolText(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                height: 1.1,
                fontFamily: 'OyunQaganTig',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white.withOpacity(0.12),
    );
  }
}
