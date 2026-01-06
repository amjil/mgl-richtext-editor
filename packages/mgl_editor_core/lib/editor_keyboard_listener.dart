import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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
    // Only handle keyboard events on desktop platforms
    // Mobile platforms should not use HardwareKeyboard
    final platform = defaultTargetPlatform;
    final isDesktop = !kIsWeb && 
                      platform != TargetPlatform.iOS && 
                      platform != TargetPlatform.android;
    
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Only handle keyboard events on desktop platforms
        // Mobile platforms should not use HardwareKeyboard
        if (!isDesktop) {
          return KeyEventResult.ignored;
        }
        
        final logicalKey = event.logicalKey;
        final keyLabel = logicalKey.keyLabel;
        
        // Let Enter key pass through to TextInputConnection for text input
        // Check this first, before processing any other events
        if (keyLabel == 'Enter') {
          return KeyEventResult.ignored;
        }
        
        // Process KeyDownEvent and KeyRepeatEvent for shortcuts/navigation
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          // Navigation keys
          final isNavigationKey = [
            'Arrow Left', 'Arrow Right', 'Arrow Up', 'Arrow Down',
            'Home', 'End', 'Page Up', 'Page Down'
          ].contains(keyLabel);

          // Modifiers (only check on desktop)
          final isMeta = HardwareKeyboard.instance.isMetaPressed || 
                         HardwareKeyboard.instance.isControlPressed;
          final isAlt = HardwareKeyboard.instance.isAltPressed;
          
          final isShortcut = isMeta || isAlt;

          if (isNavigationKey || isShortcut) {
            final handled = widget.onKeyEvent(event);
            // Always return handled for shortcuts to prevent system default behavior
            // even if the handler returns false (e.g., no selection to copy)
            return handled ? KeyEventResult.handled : KeyEventResult.handled;
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

