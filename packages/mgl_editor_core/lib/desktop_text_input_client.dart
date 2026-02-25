import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef OnDeltasCallback = void Function(List<Map<String, dynamic>> serialized);

/// Desktop IME bridge: forwards TextInput deltas to Clojure as serialized maps.
/// On mobile, virtual keyboard + sync is used instead; this client is not used there.
///
/// Serialized delta contract (each map has "type" + type-specific keys):
/// - insertion: insertionOffset, textInserted
/// - deletion: deletedRange {start, end}, selectionBaseOffset, selectionExtentOffset
/// - replacement: replacedRange {start, end}, replacementText, selectionBaseOffset, selectionExtentOffset
/// - selector: name ("deleteBackward:" | "deleteForward:")
class DesktopTextInputClient implements DeltaTextInputClient {
  TextEditingValue _currentValue = TextEditingValue.empty;
  bool updatingFromEditor = false;

  final OnDeltasCallback onDeltas;

  DesktopTextInputClient({required this.onDeltas});

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
    if (updatingFromEditor) {
      return;
    }

    final serialized = <Map<String, dynamic>>[];
    TextEditingValue updatedValue = _currentValue;

    for (var delta in deltas) {
      if (delta is TextEditingDeltaNonTextUpdate) {
        continue;
      } else if (delta is TextEditingDeltaInsertion) {
        final newText = updatedValue.text.substring(0, delta.insertionOffset) +
            delta.textInserted +
            updatedValue.text.substring(delta.insertionOffset);
        final newSelection = TextSelection.collapsed(
          offset: delta.insertionOffset + delta.textInserted.length,
        );
        updatedValue = TextEditingValue(
          text: newText,
          selection: newSelection,
        );
        if (delta.textInserted.isNotEmpty) {
          serialized.add({
            'type': 'insertion',
            'insertionOffset': delta.insertionOffset,
            'textInserted': delta.textInserted,
          });
        }
      } else if (delta is TextEditingDeltaDeletion) {
        final newText = updatedValue.text.substring(0, delta.deletedRange.start) +
            updatedValue.text.substring(delta.deletedRange.end);
        final newSelection = TextSelection.collapsed(
          offset: delta.deletedRange.start,
        );
        updatedValue = TextEditingValue(
          text: newText,
          selection: newSelection,
        );
        final deletedLen = delta.deletedRange.end - delta.deletedRange.start;
        if (deletedLen > 0) {
          serialized.add({
            'type': 'deletion',
            'deletedRange': {
              'start': delta.deletedRange.start,
              'end': delta.deletedRange.end,
            },
            'selectionBaseOffset': _currentValue.selection.baseOffset,
            'selectionExtentOffset': _currentValue.selection.extentOffset,
          });
        }
      } else if (delta is TextEditingDeltaReplacement) {
        final newText = updatedValue.text.substring(0, delta.replacedRange.start) +
            delta.replacementText +
            updatedValue.text.substring(delta.replacedRange.end);
        final newSelection = TextSelection.collapsed(
          offset: delta.replacedRange.start + delta.replacementText.length,
        );
        updatedValue = TextEditingValue(
          text: newText,
          selection: newSelection,
        );
        if (delta.replacedRange.end - delta.replacedRange.start > 0) {
          serialized.add({
            'type': 'replacement',
            'replacedRange': {
              'start': delta.replacedRange.start,
              'end': delta.replacedRange.end,
            },
            'replacementText': delta.replacementText,
            'selectionBaseOffset': _currentValue.selection.baseOffset,
            'selectionExtentOffset': _currentValue.selection.extentOffset,
          });
        } else if (delta.replacementText.isNotEmpty) {
          serialized.add({
            'type': 'insertion',
            'insertionOffset': delta.replacedRange.start,
            'textInserted': delta.replacementText,
          });
        }
      }
    }

    _currentValue = updatedValue;
    if (serialized.isNotEmpty) {
      onDeltas(serialized);
    }
  }

  @override
  void performAction(TextInputAction action) {}

  @override
  void performSelector(String selectorName) {
    onDeltas([
      {'type': 'selector', 'name': selectorName}
    ]);
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
