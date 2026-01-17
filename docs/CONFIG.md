# Configuration (POC)

Zide supports a minimal Lua config for logging only (POC).

## File locations

Zide looks for a config file in this order:

1) `.zide.lua` in the current working directory
2) `~/.config/zide/init.lua` (or `$XDG_CONFIG_HOME/zide/init.lua`)

Reference defaults live in `assets/config/init.lua` (loaded as system defaults).

If neither exists, logging falls back to `ZIDE_LOG` or defaults.

## Logging config

Config should return a table:

```lua
return {
  log = {
    enable = { "terminal", "metrics", "app" }
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

## Raylib logging

```lua
return {
  raylib = { log_level = "warning" }
}
```

Accepted `log_level` values: `none`, `error`, `warning`/`warn`, `info`, `debug`, `trace`.

## Env fallback

`ZIDE_LOG` still works as a fallback when no config file is found.

## Defaults reference policy

`assets/config/init.lua` is the authoritative defaults reference. Any change to a default
configuration option must update this file and this document in the same change.
