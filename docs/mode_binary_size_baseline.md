# Mode Binary Size Baseline

Command:

```bash
zig build mode-size-report
```

Snapshot date: 2026-03-05

| Binary | Size (bytes) |
|---|---:|
| `zide` | 41,595,884 |
| `zide-terminal` | 41,507,101 |
| `zide-editor` | 41,508,103 |
| `zide-ide` | 41,506,678 |

Notes:

- These values are debug-build artifacts from `zig-out/bin/`.
- Track deltas after each compile-time split slice.
