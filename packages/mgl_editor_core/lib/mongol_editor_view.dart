import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'editor_keyboard_listener.dart';

class MongolEditorView extends StatefulWidget {
  final Widget content;
  final Widget? findReplaceDialog;
  final Widget? selectionMenu;
  final Widget? slashCommandMenu;
  final Widget? selectionHandles;
  final VoidCallback? onPostFrame;
  final bool hasSelection;
  final bool Function(KeyEvent) onKeyEvent;
  final ValueChanged<Map<String, dynamic>>? onChange;

  const MongolEditorView({
    super.key,
    required this.content,
    this.findReplaceDialog,
    this.selectionMenu,
    this.slashCommandMenu,
    this.selectionHandles,
    this.onPostFrame,
    this.hasSelection = false,
    required this.onKeyEvent,
    this.onChange,
  });

  @override
  State<MongolEditorView> createState() => _MongolEditorViewState();
}

class _MongolEditorViewState extends State<MongolEditorView> {
  @override
  void didUpdateWidget(MongolEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger post-frame callback if selection exists
    if (widget.hasSelection && widget.onPostFrame != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPostFrame!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EditorKeyboardListener(
        onKeyEvent: widget.onKeyEvent,
        child: Stack(
          children: [
            widget.content,
            if (widget.findReplaceDialog != null) widget.findReplaceDialog!,
            if (widget.selectionMenu != null) widget.selectionMenu!,
            if (widget.slashCommandMenu != null) widget.slashCommandMenu!,
            if (widget.selectionHandles != null) widget.selectionHandles!,
          ],
        ),
      ),
    );
  }
}
