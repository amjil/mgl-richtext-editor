import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef KeyEventHandler = bool Function(KeyEvent event);

class EditorKeyboardListener extends StatefulWidget {
  final Widget child;
  final KeyEventHandler onKeyEvent;

  const EditorKeyboardListener({
    super.key,
    required this.child,
    required this.onKeyEvent,
  });

  @override
  State<EditorKeyboardListener> createState() => _EditorKeyboardListenerState();
}

class _EditorKeyboardListenerState extends State<EditorKeyboardListener> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Only process KeyDownEvent for shortcuts/navigation
        if (event is KeyDownEvent) {
          final logicalKey = event.logicalKey;
          final keyLabel = logicalKey.keyLabel;
          
          // Navigation keys
          final isNavigationKey = [
            'Arrow Left', 'Arrow Right', 'Arrow Up', 'Arrow Down',
            'Home', 'End', 'Page Up', 'Page Down'
          ].contains(keyLabel);

          // Modifiers
          final isMeta = HardwareKeyboard.instance.isMetaPressed || 
                         HardwareKeyboard.instance.isControlPressed;
          final isAlt = HardwareKeyboard.instance.isAltPressed;
          
          final isShortcut = isMeta || isAlt;

          if (isNavigationKey || isShortcut) {
            final handled = widget.onKeyEvent(event);
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) {
          _focusNode.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}

