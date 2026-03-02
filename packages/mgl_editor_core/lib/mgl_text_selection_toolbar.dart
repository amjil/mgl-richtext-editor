import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart';

class MglTextSelectionToolbar extends StatelessWidget {
  final LayerLink layerLink;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  const MglTextSelectionToolbar({
    super.key,
    required this.layerLink,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: false,
      // Mongol selection is usually on the left; place toolbar 30px to the right
      offset: const Offset(30, 0), 
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          );
        },
        child: Material(
          elevation: 12,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 56,
            color: const Color(0xFF2C2C2C),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(Icons.copy, 'ᠪᠠᠭᠠᠪᠤᠷᠯᠠᠬᠤ', onCopy),
                _buildDivider(),
                _buildMenuItem(Icons.paste, 'ᠨᠠᠭᠠᠬᠤ', onPaste),
                _buildDivider(),
                _buildMenuItem(Icons.select_all, 'ᠪᠦᠭᠦᠳᠡ ᠶᠢ ᠰᠣᠩᠭᠣᠬᠤ', onSelectAll),
                _buildDivider(),
                _buildMenuItem(Icons.delete_outline, 'ᠤᠰᠠᠳᠬᠠᠬᠤ', onDelete, color: Colors.redAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.15),
      highlightColor: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            // Vertical menu labels via MongolText
            MongolText(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      width: 36,
      color: Colors.white.withOpacity(0.1),
    );
  }
}