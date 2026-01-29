# Configuration (POC)

Zide supports a minimal Lua config for logging only (POC).

## File locations

Zide loads config in this order:

1) `assets/config/init.lua` (system defaults)
2) User config:
   - Linux: `$XDG_CONFIG_HOME/zide/init.lua` (fallback `~/.config/zide/init.lua`)
   - macOS: `~/Library/Application Support/Zide/init.lua`
   - Windows: `%APPDATA%\\Zide\\init.lua`
3) `.zide.lua` in the current working directory (project override)

## Logging config

Config should return a table:

```lua
return {
  log = {
    enable = {
      "app.core",
      "terminal.core",
      "terminal.metrics",
      "terminal.alt",
      "terminal.io",
      "terminal.csi",
      "terminal.sgr",
      "terminal.osc",
      "terminal.font",
    },
    -- file = { "terminal.metrics" },
    -- console = { "app.core" },
  }
}
```

You can also return a string:

```lua
return {
  log = "all"
}
```

Supported values:
- `all` — enable all loggers
- `none` — disable all loggers
- comma-separated list (via `enable` array)
- `file` / `console` arrays for per-destination control

Common logger tags:
- `app.core`
- `terminal.core`
- `terminal.metrics`
- `terminal.alt` (alt-screen timing)
- `terminal.io` (PTY IO timing)
- `terminal.csi` (CSI trace)
- `terminal.sgr` (SGR trace)
- `terminal.osc` (OSC trace)
- `terminal.font`

## SDL logging

```lua
return {
  sdl = { log_level = "warning" }
}
```

Accepted `log_level` values: `none`, `critical`, `error`, `warning`/`warn`, `info`, `debug`, `trace`.

## Theme config

Theme applies across the app shell, editor, and terminal.

```lua
return {
  theme = {
    palette = {
      background = "#242933",
      foreground = "#BBC3D4",
      selection = "#3B4252",
      cursor = "#D8DEE9",
      link = "#81A1C1",
      line_number = "#4C566A",
      line_number_bg = "#1E222A",
      current_line = "#191D24",
    },
    syntax = {
      comment = "#4C566A",
      string = "#A3BE8C",
      keyword = "#D08770",
      number = "#BE9DB8",
      ["function"] = "#88C0D0",
      variable = "#BBC3D4",
      type_name = "#EBCB8B",
      operator = "#BBC3D4",
      builtin = "#5E81AC",
      punctuation = "#60728A",
      constant = "#BE9DB8",
      attribute = "#8FBCBB",
      namespace = "#E7C173",
      label = "#D08770",
      error = "#C5727A",
    },
  }
}
```

## Font config

Editor + terminal currently share the same font stack. You can set it under `app.font`
or override it under `editor.font` / `terminal.font` (last one wins).

```lua
return {
  app = {
    font = { path = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf", size = 16 },
  },
  editor = {
    -- font = { path = "/usr/share/fonts/...", size = 16 },
  },
  terminal = {
    -- font = { path = "/usr/share/fonts/...", size = 16 },
  },
}
```

## Env fallback

Env fallbacks:
- `ZIDE_LOG` applies to both file and console if no config is present.
- `ZIDE_LOG_FILE` / `ZIDE_LOG_CONSOLE` override per destination.

## Defaults reference policy

`assets/config/init.lua` is the authoritative defaults reference. Any change to a default
configuration option must update this file and this document in the same change.
