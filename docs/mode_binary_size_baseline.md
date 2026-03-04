# Mode Binary Size Baseline

Command:

```bash
zig build mode-size-report
```

Snapshot date: 2026-03-05

| Binary | Size (bytes) |
|---|---:|
| `zide` | 41,638,376 |
| `zide-terminal` | 41,406,606 |
| `zide-editor` | 41,405,368 |
| `zide-ide` | 41,404,615 |

Notes:

- These values are debug-build artifacts from `zig-out/bin/`.
- Track deltas after each compile-time split slice.
