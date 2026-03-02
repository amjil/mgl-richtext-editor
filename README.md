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
├── config.cljd       # Config skeleton + merge-config(base, user-config); avoids service deps to prevent cycles
├── defaults.cljd     # Full default config (including command implementations) + defaults/merge-config(user-config)
├── commands/         # Commands (editor, text, block)
├── components/       # UI (editor-root, node-view)
├── model/            # Models (node, selection, delta, transaction)
└── services/         # Services (IME, history, clipboard, serialization)
```

## Getting Started

### Prerequisites

- Clojure CLI (`clj` command)
- Flutter SDK
- iOS Simulator (for macOS) or Android Emulator

### Running the Example

1. Install the Clojure CLI (`clj`) if you don't have it yet.
2. Fetch Flutter dependencies for the example app:
   ```bash
   cd example
   flutter pub get
   ```
3. Initialize ClojureDart/Flutter integration:
   ```bash
   clj -M:cljd init
   ```
4. Start a simulator/emulator (optional, depending on your setup):
   ```bash
   open -a Simulator  # macOS
   ```
5. Run the app:
   ```bash
   clj -M:cljd flutter
   ```

## Usage

### Basic usage

Mount the editor in your Flutter app (see `example/` for a working reference):

```clojure
(ns your-app.main
  (:require [rich-editor.components.editor-root :as editor-root]))

;; Your editor state atom should contain keys like:
;; :root :blocks :active-block-id :cursor-visible :selection :history ...
(editor-root/editor-container !state)
```

### Highly customizable

The editor is driven by a **config** map, which makes block types, inline formatting, commands, and shortcuts pluggable. You can extend behavior without modifying the library code.

#### Config entry points

- **No config provided**: uses `defaults/full-default-config` (default block styles, bold/italic/underline/link, common shortcuts like Ctrl+Z/X/C/V/B/I/U/K, etc.).
- **Custom config**: build it via `(defaults/merge-config user-config)` and pass the merged result to `editor-container`.

```clojure
(require '[rich-editor.defaults :as defaults])
(editor-root/editor-container !state (defaults/merge-config {:default-block-type :heading-1}))
```

#### Customizable options

| Key | Description | Example |
|--------|------|------|
| `:block-style` | Block-level style: `(fn [block-type] -> TextStyle)` or `{block-type -> TextStyle}` | Customize headings/quotes/code blocks |
| `:inline-format-applier` | Inline formatting: `(fn [base-style attrs] -> TextStyle)` | Add new attrs like color/font |
| `:text-block-types` | Set of editable text block types | Add `:callout` with matching `:block-style` |
| `:default-block-type` | Default type when inserting/splitting blocks | `:paragraph`, `:heading-1`, etc. |
| `:commands` | Command table: `intent -> (fn [!state] ...)`, merged with defaults | Add `:insert-table`, override `:link`, etc. |
| `:shortcuts` | Shortcut list: `[[SingleActivator intent] ...]`, replaces defaults | Remap keys or add new shortcuts |
| `:custom-block-renderers` | Custom rendering: `block-type -> (fn [id !state root-index block style cfg] -> Widget)` | Fully custom UI for a block type (video/embed) |

#### Example: change default block type and heading style

```clojure
(require ["package:flutter/material.dart" :as m]
         [rich-editor.config :as config]
         [rich-editor.components.editor-root :as editor-root])

(require '[rich-editor.defaults :as defaults])

(def my-config
  (defaults/merge-config
   {:default-block-type :paragraph
    :block-style (fn [block-type]
                   (case block-type
                     :heading-1 (m/TextStyle. .fontSize 32.0 .fontWeight m.FontWeight/bold .height 1.5)
                     (config/default-block-style block-type))}))

(editor-root/editor-container !state my-config)
```

#### Example: add a command and a shortcut

```clojure
(require ["package:flutter/services.dart" :as s])

(def my-config
  (defaults/merge-config
   {:commands {:my-action (fn [!state] (dart:core/print "custom action"))}
    :shortcuts (conj (:shortcuts defaults/full-default-config)
                     [(m/SingleActivator. (.-keyS s/LogicalKeyboardKey) .control true) :my-action])}))
;; Note: :commands are merged with defaults. :shortcuts replace defaults, so we append to the default list explicitly.
```

#### Custom block rendering

For non-text blocks (images, video, embeds, etc.), provide a renderer in `:custom-block-renderers`. The renderer receives `id !state root-index block style cfg` and returns a Flutter `Widget`. Unregistered types fall back to built-in rendering (for example, `:image` may use `Image.network`).

## Credits

Made possible by the following projects:

- [suragch/mongol](https://github.com/suragch/mongol) - Mongolian vertical script widgets for Flutter apps
- [tensegritics/ClojureDart](https://github.com/tensegritics/ClojureDart) - Clojure for Flutter
