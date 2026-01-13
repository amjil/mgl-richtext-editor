# mgl_richtext_editor

A rich text editor built with ClojureDart for Flutter, specifically designed for Mongolian vertical script text editing. This editor provides a comprehensive set of features for creating and editing formatted documents with full support for traditional Mongolian script.

## Features

### Core Editing
- **Rich Text Formatting**: Bold, italic, underline, strikethrough
- **Text Styling**: Font family, font size, text color, background color
- **Block-level Formatting**: Paragraph alignment, block background colors, block text colors
- **Undo/Redo**: Full history management with transaction-based undo/redo system

### Mongolian Script Support
- **Vertical Text Layout**: Native support for Mongolian vertical script rendering
- **Mongolian Virtual Keyboard**: Integrated virtual keyboard for mobile platforms
- **Text Selection**: Advanced selection handling for vertical text
- **Cursor Navigation**: Proper cursor movement in vertical text layout

### Advanced Features
- **Slash Commands**: Quick command insertion via slash commands (e.g., `/heading`, `/list`)
- **Markdown Support**: Import and export documents in Markdown format
- **HTML Export**: Export documents to HTML format
- **Find & Replace**: Search and replace functionality within documents
- **Table Support**: Create and edit tables within documents
- **Link Management**: Insert and edit hyperlinks

### Architecture
- **Modular Design**: Well-organized command system, UI components, and services
- **Functional Programming**: Built with functional programming principles using ClojureDart
- **Event System**: Reactive event bus for state management
- **Error Handling**: Result type-based error handling system
- **Validation**: Comprehensive validation utilities for positions, selections, and documents

## Technology Stack

- **ClojureDart**: Functional programming language for Flutter
- **Flutter**: Cross-platform UI framework
- **Mongol Package**: Mongolian vertical script widgets

## Project Structure

```
src/rich_editor/
├── command/          # Command modules (formatting, clipboard, navigation, etc.)
├── model/            # Data models (node, selection, delta, transaction)
├── services/         # Service layer (keyboard, virtual keyboard, search, etc.)
├── ui/               # UI components (block view, menus, dialogs, etc.)
└── utils/            # Utility modules (result, validation, events, etc.)
```

## Getting Started

### Prerequisites

- Clojure CLI (`clj` command)
- Flutter SDK
- iOS Simulator (for macOS) or Android Emulator

### Running the Example

1. Install the `clj` command (if not already installed)
2. Initialize the example project:
   ```bash
   clj -M:cljd init
   ```
3. Open a simulator:
   ```bash
   open -a Simulator  # macOS
   ```
4. Run the Flutter app:
   ```bash
   clj -M:cljd flutter
   ```

## Usage

The editor can be integrated into your Flutter app using the `mongol-editor-view` component:

```clojure
(ns your-app.main
  (:require [rich-editor.ui.editor-main :refer [mongol-editor-view]]))

(mongol-editor-view)
```

## Credits

Made possible by the following projects:

- [suragch/mongol](https://github.com/suragch/mongol) - Mongolian vertical script widgets for Flutter apps
- [tensegritics/ClojureDart](https://github.com/tensegritics/ClojureDart) - Clojure for Flutter
