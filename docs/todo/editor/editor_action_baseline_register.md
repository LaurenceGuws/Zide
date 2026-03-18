# Editor Action Baseline Register

This is a practical baseline checklist derived from common editor shortcut
surfaces we want to compare against during baseline work.

It is not a mandate to clone any one editor exactly.

Concrete key mappings remain Lua/config-owned.

This file is only an implementation checklist for:

- expected editor behaviors worth supporting
- useful reference bindings from mainstream editors
- feature parity tracking while the actual binding policy stays in Lua

Use it as:

- a shorthand register of expected "basic editor" behavior
- a gap list while filling `ED-APP-04` in `app_baseline.md`
- a filter for "worth doing now" vs "defer until the app actually owns that surface"

Status meaning:

- `[x]` implemented or intentionally mapped already
- `[ ]` relevant gap worth considering
- `[-]` explicitly deferred or currently out of scope

## Reference Sources

- Notepad++-style basic editor/file/search expectations
- VS Code-style editor/app/workbench expectations

## Shared High-Signal Baseline Set

These are the shortcuts most worth tracking first because they show up across
multiple mainstream editors and fit Zide's current Notepad-grade lane.

### File and Document Flow

The bindings shown here are reference examples, not hardcoded key policy.

- [x] `Ctrl+O` Open file
- [x] `Ctrl+N` New file
- [x] `Ctrl+S` Save file
- [x] `Ctrl+Shift+S` Save As
- [x] `Ctrl+W` Close current document
- [x] `Ctrl+Tab` Next document
- [x] `Ctrl+Shift+Tab` Previous document
- [ ] `Ctrl+PgUp` Next document
- [ ] `Ctrl+PgDn` Previous document
- [ ] `Ctrl+1..9` Focus document by tab index

### Core Editing

- [x] `Ctrl+C` Copy
- [x] `Ctrl+X` Cut
- [x] `Ctrl+V` Paste
- [x] `Ctrl+Z` Undo
- [x] `Ctrl+Y` Redo
- [x] `Ctrl+A` Select all
- [ ] `Ctrl+D` Duplicate current line / selection to next match depending on mode
- [x] `Ctrl+Shift+K` Delete line
- [ ] `Alt+Up` Move line up
- [ ] `Alt+Down` Move line down
- [ ] `Shift+Alt+Up` Copy line up
- [ ] `Shift+Alt+Down` Copy line down
- [ ] `Ctrl+Enter` Insert line below
- [ ] `Ctrl+Shift+Enter` Insert line above
- [ ] `Tab` indent selected full lines
- [ ] `Shift+Tab` outdent selected full lines
- [ ] `Ctrl+Backspace` Delete to start of word
- [ ] `Ctrl+Delete` Delete to end of word
- [ ] `Ctrl+Shift+Backspace` Delete to start of line
- [ ] `Ctrl+Shift+Delete` Delete to end of line

### Search and Navigation

- [x] `Ctrl+F` Find
- [x] `Ctrl+H` Replace
- [x] `F3` Find next
- [x] `Shift+F3` Find previous
- [x] `Ctrl+G` Go to line
- [ ] `Ctrl+Shift+\\` Jump to matching bracket
- [ ] `Home` Go to beginning of line
- [ ] `End` Go to end of line
- [ ] `Ctrl+Home` Go to beginning of file
- [ ] `Ctrl+End` Go to end of file

### Multi-Cursor and Selection

- [x] `Alt+Click` Insert cursor / rectangular selection style input
- [x] `Ctrl+Left Click` Add selected area / caret
- [x] `Alt+Shift+Arrow` Column-mode style expansion
- [ ] `Ctrl+Alt+Up` Insert cursor above
- [ ] `Ctrl+Alt+Down` Insert cursor below
- [ ] `Ctrl+L` Select current line
- [ ] Triple click selects line

### Display and Shell

- [x] `Ctrl++` Zoom in
- [x] `Ctrl+-` Zoom out
- [x] `Ctrl+0` Zoom reset
- [ ] `F11` Toggle full screen
- [ ] `Alt+F4` Exit

## Notepad++ Reference Register

Reference binding surface only. Use it to ask "do we support this editor
behavior?" not "must this exact key combo be hardcoded?"

## File

- [x] `Ctrl+O` Open file
- [x] `Ctrl+N` New file
- [x] `Ctrl+S` Save file
- [x] `Ctrl+Shift+S` Save As
- [ ] `Ctrl+Shift+S` Save all
- [-] `Ctrl+P` Print
- [ ] `Alt+F4` Exit
- [ ] `Ctrl+Tab` Next document
- [ ] `Ctrl+Shift+Tab` Previous document
- [ ] `Ctrl+1..9` Focus document by tab index
- [ ] `Ctrl+PgUp` Next document
- [ ] `Ctrl+PgDn` Previous document
- [x] `Ctrl+W` Close current document
- [x] `Ctrl+Tab` Next document
- [x] `Ctrl+Shift+Tab` Previous document

## Edit

- [x] `Ctrl+C` Copy
- [ ] `Ctrl+Insert` Copy
- [ ] `Ctrl+Shift+T` Copy current line
- [x] `Ctrl+X` Cut
- [ ] `Shift+Delete` Cut
- [x] `Ctrl+V` Paste
- [ ] `Shift+Insert` Paste
- [x] `Ctrl+Z` Undo
- [ ] `Alt+Backspace` Undo
- [x] `Ctrl+Y` Redo
- [x] `Ctrl+A` Select all
- [x] `Alt+Shift+Arrow` Column-mode style multi-caret expansion
- [x] `Alt+Left Click` Column-mode style rectangular selection
- [x] `Ctrl+Left Click` Start new selected area / add caret
- [-] `Alt+C` Column editor
- [ ] `Ctrl+D` Duplicate current line
- [ ] `Ctrl+T` Transpose current line with previous line
- [ ] `Ctrl+Shift+Up` Move current line or selection up
- [ ] `Ctrl+Shift+Down` Move current line or selection down
- [ ] `Ctrl+L` Delete current line
- [ ] `Ctrl+I` Split lines
- [ ] `Ctrl+J` Join lines
- [x] `Ctrl+G` Go to line
- [ ] `Ctrl+Q` Single-line comment
- [ ] `Ctrl+Shift+Q` Single-line uncomment
- [ ] `Ctrl+K` Toggle single-line comment
- [ ] `Ctrl+Shift+K` Block comment
- [ ] `Tab` indent selected full lines
- [ ] `Shift+Tab` outdent selected full lines
- [ ] `Ctrl+Backspace` Delete to start of word
- [ ] `Ctrl+Delete` Delete to end of word
- [ ] `Ctrl+Shift+Backspace` Delete to start of line
- [ ] `Ctrl+Shift+Delete` Delete to end of line
- [ ] `Ctrl+U` Lowercase selection
- [ ] `Ctrl+Shift+U` Uppercase selection
- [ ] `Ctrl+B` Go to matching brace
- [-] `Ctrl+Space` Calltip listbox
- [-] `Ctrl+Shift+Space` Function completion listbox
- [-] `Ctrl+Alt+Space` Path completion listbox
- [-] `Ctrl+Enter` Word completion listbox
- [-] `Ctrl+Alt+R` Text direction RTL
- [-] `Ctrl+Alt+L` Text direction LTR
- [ ] `Enter` Split line / new line
- [ ] `Shift+Enter` Split line / new line variant
- [ ] `Ctrl+Alt+Enter` Insert unindented line above
- [ ] `Ctrl+Alt+Shift+Enter` Insert unindented line below

## Search

- [x] `Ctrl+F` Find
- [x] `Ctrl+H` Replace
- [x] `F3` Find next
- [x] `Shift+F3` Find previous
- [-] `Ctrl+Shift+F` Find in files
- [-] `F7` Search results pane focus
- [-] `Ctrl+Alt+F3` Volatile find next
- [-] `Ctrl+Alt+Shift+F3` Volatile find previous
- [-] `Ctrl+F3` Select and find next
- [-] `Ctrl+Shift+F3` Select and find previous
- [-] `F4` Go to next found result
- [-] `Shift+F4` Go to previous found result
- [-] `Ctrl+Shift+I` Incremental search
- [-] `Ctrl+0..5` Jump between marked results
- [-] `Ctrl+Shift+0..5` Jump upward between marked results
- [-] `Ctrl+F2` Toggle bookmark
- [-] `F2` Next bookmark
- [-] `Shift+F2` Previous bookmark
- [ ] `Ctrl+B` Go to matching brace
- [-] `Ctrl+Alt+B` Select all between matching braces

## View

- [x] `Ctrl++` Zoom in
- [x] `Ctrl+-` Zoom out
- [x] `Ctrl+0` Zoom reset
- [-] `Ctrl+Mouse Wheel` Zoom
- [-] `F11` Full screen
- [-] `F12` Post-it mode
- [-] Folding shortcuts

## Macro / Run / Help

- [-] Macro recording/playback shortcuts
- [-] Run dialog and external tool shortcuts
- [-] Help/About shortcuts

## Mouse

- [x] Single left click sets caret/current line
- [-] Single left click on status-bar typing-mode pane
- [-] Single left click on bookmark margin
- [-] Shift+left click fold expansion cascade
- [-] Ctrl+left click fold toggle cascade
- [x] Right click opens context menu where available
- [x] Double left click selects word
- [-] Double left click on location pane goes to line
- [ ] Triple left click selects line

## Current Baseline Priorities

These are the highest-signal follow-ups from this register for Zide's current
Notepad-grade lane:

1. duplicate/delete/move line operations
2. indent/outdent for selected full lines
3. line operations and insert-line behaviors
4. tab-index and page-style document navigation
5. simple destructive-flow guards for dirty buffers

## VS Code Reference Register

This section is not a worklist by itself. It is a second reference surface for
deciding what "normal" editor behavior looks like when Zide grows beyond the
bare Notepad-style baseline.

Again: these are reference bindings for implementation checks. Actual shipped
bindings should stay Lua-driven.

### General

- [-] `Ctrl+Shift+P` / `F1` Command palette
- [-] `Ctrl+P` Quick open / go to file
- [-] `Ctrl+Shift+N` New window
- [-] `Ctrl+Shift+W` Close window
- [-] `Ctrl+,` User settings
- [-] `Ctrl+K Ctrl+S` Keyboard shortcuts UI

### Basic Editing

- [x] `Ctrl+X` Cut line when selection is empty via normal cut baseline support
- [x] `Ctrl+C` Copy line when selection is empty via normal copy baseline support
- [ ] `Alt+Up` / `Alt+Down` Move line up/down
- [ ] `Shift+Alt+Down` / `Shift+Alt+Up` Copy line down/up
- [x] `Ctrl+Shift+K` Delete line
- [ ] `Ctrl+Enter` Insert line below
- [ ] `Ctrl+Shift+Enter` Insert line above
- [ ] `Ctrl+Shift+\\` Jump to matching bracket
- [ ] `Ctrl+]` indent line
- [ ] `Ctrl+[` outdent line
- [ ] `Home` / `End` line start/end
- [ ] `Ctrl+Home` beginning of file
- [ ] `Ctrl+End` end of file
- [-] `Ctrl+Up` / `Ctrl+Down` scroll line up/down
- [-] `Alt+PgUp` / `Alt+PgDn` scroll page up/down
- [-] Folding shortcuts
- [ ] `Ctrl+K Ctrl+C` Add line comment
- [ ] `Ctrl+K Ctrl+U` Remove line comment
- [ ] `Ctrl+/` Toggle line comment
- [ ] `Shift+Alt+A` Toggle block comment
- [ ] `Alt+Z` Toggle word wrap

### Navigation

- [-] `Ctrl+T` Show all symbols
- [x] `Ctrl+G` Go to line
- [-] `Ctrl+P` Go to file
- [-] `Ctrl+Shift+O` Go to symbol
- [-] Problems/error navigation shortcuts
- [x] `Ctrl+Shift+Tab` editor history / previous document style navigation
- [-] `Alt+Left` / `Alt+Right` go back/forward

### Search and Replace

- [x] `Ctrl+F` Find
- [x] `Ctrl+H` Replace
- [x] `F3` / `Shift+F3` next/previous find
- [-] `Alt+Enter` Select all occurrences of find match
- [ ] `Ctrl+D` add next selection / duplicate-style conflict needs policy
- [-] `Ctrl+K Ctrl+D` move last selection to next find match
- [-] Find option toggles

### Multi-Cursor and Selection

- [x] `Alt+Click` Insert cursor
- [ ] `Ctrl+Alt+Up` / `Ctrl+Alt+Down` Insert cursor above/below
- [-] `Ctrl+U` Undo last cursor operation
- [ ] `Shift+Alt+I` Insert cursor at end of each selected line
- [ ] `Ctrl+L` Select current line
- [-] `Ctrl+Shift+L` Select all occurrences of selection
- [-] `Ctrl+F2` Select all occurrences of current word
- [-] `Shift+Alt+Right` expand selection
- [-] `Shift+Alt+Left` shrink selection
- [x] Box selection via mouse/column interaction
- [-] Box selection via keyboard

### Rich Language Editing

- [-] Suggestions, parameter hints, formatting, definitions, quick fix, references, rename

### Editor Management

- [x] `Ctrl+F4` / `Ctrl+W` Close editor
- [-] Explorer/workspace folder management
- [-] Split editor and editor groups
- [x] `Ctrl+Tab` next editor
- [x] `Ctrl+Shift+Tab` previous editor

### File Management

- [x] `Ctrl+N` New file
- [x] `Ctrl+O` Open file
- [x] `Ctrl+S` Save
- [x] `Ctrl+Shift+S` Save As
- [ ] `Ctrl+K S` Save all
- [x] `Ctrl+F4` Close
- [-] Close all / reopen closed / copy path / reveal file / open in new window

### Display

- [ ] `F11` Full screen
- [x] `Ctrl+=` / `Ctrl+-` Zoom in/out
- [-] Sidebar/workbench panels and zen-mode shortcuts

### Debug / Terminal / Workbench

- [-] Debug shortcuts
- [x] `Ctrl+\`` Toggle terminal
- [ ] `Ctrl+Shift+\`` New terminal
- [-] terminal scrolling/workbench navigation shortcuts
