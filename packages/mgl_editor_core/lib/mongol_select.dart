import 'package:flutter/material.dart';

/// Mongol Select Item
class MongolSelectItem<T> {
  final T value;
  final Widget label;

  /// Optional: group title (vertical MongolText)
  final Widget? group;

  const MongolSelectItem({
    required this.value,
    required this.label,
    this.group,
  });
}

/// MongolSelect
/// - Vertical writing
/// - Left/right popup
/// - Horizontal scrolling
/// - Design System level
class MongolSelect<T> extends StatefulWidget {
  final T value;
  final List<MongolSelectItem<T>> items;
  final ValueChanged<T> onChanged;

  /// Current value display
  final Widget Function(T value) valueBuilder;

  /// Menu width
  final double menuWidth;

  /// Maximum height
  final double maxHeight;

  /// Whether to open to the left (recommended true for Mongolian)
  final bool openToLeft;

  /// Whether to show arrow
  final bool showArrow;

  const MongolSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.valueBuilder,
    this.menuWidth = 200,
    this.maxHeight = 320,
    this.openToLeft = true,
    this.showArrow = true,
  });

  @override
  State<MongolSelect<T>> createState() => _MongolSelectState<T>();
}

class _MongolSelectState<T> extends State<MongolSelect<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    if (_overlay != null) {
      _overlay?.remove();
      _overlay = null;
    }
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlay == null) {
      _show();
    } else {
      _remove();
    }
  }

  void _show() {
    _overlay = OverlayEntry(
      builder: (context) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _remove,
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: widget.openToLeft
                  ? Offset(-widget.menuWidth, 0) // Open to the left
                  : Offset.zero, // Open to the right
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.none,
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: widget.openToLeft
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: _buildMenu(context),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    _controller.forward(from: 0);
  }

  Future<void> _remove() async {
    if (_overlay == null) return;
    if (mounted) {
      await _controller.reverse();
    }
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);

    Widget? currentGroup;
    final menuItems = <Widget>[];

    for (final item in widget.items) {
      // Add group header if this item has a different group
      final group = item.group;
      if (group != null && group != currentGroup) {
        currentGroup = group;
        menuItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.hintColor),
              child: group,
            ),
          ),
        );
      }

      // Add menu item
      final selected = item.value == widget.value;
      menuItems.add(
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            widget.onChanged(item.value);
            _remove();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: item.label,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.maxHeight,
        minWidth: widget.menuWidth,
      ),
      child: Container(
        width: widget.menuWidth,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Colors.black26,
            ),
          ],
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: false,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          children: menuItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.valueBuilder(widget.value),
            if (widget.showArrow)
              const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

