import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef TextCommandCallback = void Function(String text);
typedef VoidCommandCallback = void Function();

class DesktopTextInputClient implements DeltaTextInputClient {
  TextEditingValue _currentValue = TextEditingValue.empty;
  bool updatingFromEditor = false;

  final TextCommandCallback onInsertText;
  final VoidCommandCallback onDeleteSelection;
  final VoidCommandCallback onDeleteBackward;
  final VoidCommandCallback onDeleteForward;

  DesktopTextInputClient({
    required this.onInsertText,
    required this.onDeleteSelection,
    required this.onDeleteBackward,
    required this.onDeleteForward,
  });

  void updateState(TextEditingValue value) {
    _currentValue = value;
  }

  @override
  TextEditingValue? get currentTextEditingValue => _currentValue;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (updatingFromEditor) return;
    _currentValue = value;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    if (updatingFromEditor) return;
    
    for (var delta in deltas) {
      if (delta is TextEditingDeltaInsertion) {
        if (delta.textInserted.isNotEmpty) {
          onInsertText(delta.textInserted);
        }
      } else if (delta is TextEditingDeltaDeletion) {
        final deletedLen = delta.deletedRange.end - delta.deletedRange.start;
        if (deletedLen > 0) {
          // Robust check: if IME asks to delete, and we have no selection, it MUST be a backspace/delete.
          // We prefer onDeleteBackward for single character deletions to trigger block merging.
          if (!_currentValue.selection.isCollapsed) {
            onDeleteSelection();
          } else {
            // macOS backspace behavior: deleted range is usually the character just before baseOffset.
            if (delta.deletedRange.end <= _currentValue.selection.baseOffset) {
              onDeleteBackward();
            } else {
              onDeleteForward();
            }
          }
        }
      } else if (delta is TextEditingDeltaReplacement) {
        if (delta.replacedRange.end - delta.replacedRange.start > 0) {
          if (!_currentValue.selection.isCollapsed) {
            onDeleteSelection();
          } else {
            onDeleteBackward();
          }
        }
        if (delta.replacementText.isNotEmpty) {
          onInsertText(delta.replacementText);
        }
      }
    }
  }

  @override
  void performAction(TextInputAction action) {
    // Handled via deltas
  }

  @override
  void performSelector(String selectorName) {
    if (selectorName == 'deleteBackward:') {
      onDeleteBackward();
    } else if (selectorName == 'deleteForward:') {
      onDeleteForward();
    }
  }

  @override void connectionClosed() {}
  @override void insertTextPlaceholder(Size size) {}
  @override void removeTextPlaceholder() {}
  @override void showAutocorrectionPromptRect(int start, int end) {}
  @override void showToolbar() {}
  @override void updateFloatingCursor(RawFloatingCursorPoint point) {}
  @override void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {}
  @override void performPrivateCommand(String action, Map<String, dynamic> data) {}
  @override void insertContent(KeyboardInsertedContent content) {}
  @override AutofillScope? get currentAutofillScope => null;
}
