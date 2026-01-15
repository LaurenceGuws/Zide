# Zide - Zig IDE

A cross-platform IDE for Zig development, built with Zig.

## Features

- **Text Editor**: Piece-table based text buffer with undo/redo
- **Syntax Highlighting**: Tree-sitter based, with Zig language support
- **Integrated Terminal**: libvterm-based terminal emulator
- **Cross-platform**: Windows, Linux, and macOS support

## Architecture

```
zide/
├── src/
│   ├── main.zig              # Application entry point
│   ├── editor/               # Text editing engine
│   │   ├── buffer.zig        # Piece-table text buffer
│   │   ├── editor.zig        # High-level editor API
│   │   ├── syntax.zig        # Tree-sitter syntax highlighting
│   │   └── types.zig         # Data structures
│   ├── terminal/             # Terminal emulator
│   │   ├── terminal.zig      # Terminal session management
│   │   ├── vterm.zig         # libvterm wrapper
│   │   ├── pty_unix.zig      # Unix PTY backend
│   │   └── pty_windows.zig   # Windows ConPTY backend
│   └── ui/                   # User interface
│       ├── renderer.zig      # raylib rendering abstraction
│       └── widgets.zig       # UI components
├── vendor/                   # External dependencies
│   └── libvterm/             # Terminal emulation library
├── build.zig                 # Zig build configuration
└── build.zig.zon             # Package dependencies
```

## Dependencies

- **raylib**: Cross-platform graphics/input (fetched via Zig package manager)
- **libvterm**: Terminal emulation (fetched via bootstrap script)
- **tree-sitter**: Syntax parsing (bundled in old_editor_lib/)

## Bootstrap

Fetch vendor dependencies:

```bash
./scripts/bootstrap.sh
```

Options:
- `LIBVTERM_REF=v0.3.3` - Override libvterm version
- `FORCE=1` - Force re-download

## Build

```bash
zig build
```

## Run

```bash
zig build run
```

## Test

```bash
zig build test
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+N | New file |
| Ctrl+O | Open file |
| Ctrl+S | Save file |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| Ctrl+` | Toggle terminal |
| Ctrl+Q | Quit |

## Roadmap

- [ ] File tree sidebar
- [ ] Multiple split panes
- [ ] LSP integration (ZLS)
- [ ] Git integration
- [ ] Search/replace
- [ ] libghostty migration (when Windows support matures)
