# LCD Snapshot Artifacts

This folder stores dated LCD experiment artifacts for Phase 5.

Create a snapshot:

```bash
tools/font_sample_lcd_snapshot.sh
```

Or with an explicit stamp:

```bash
tools/font_sample_lcd_snapshot.sh 2026-02-17
```

or:

```bash
tools/font_sample_lcd_snapshot.sh --stamp 2026-02-17
```

Preview planned outputs only:

```bash
tools/font_sample_lcd_snapshot.sh --dry-run
```

Skip capture and refresh reports from existing LCD captures:

```bash
tools/font_sample_lcd_snapshot.sh --stamp 2026-02-17 --no-capture
```

Validate all dated snapshots:

```bash
tools/font_sample_lcd_snapshot_check.sh
```

Validate only the newest snapshot:

```bash
tools/font_sample_lcd_snapshot_check.sh --latest
```

Per snapshot folder (`YYYY-MM-DD`), the expected files are:

- `lcd_report.txt`
- `lcd_report.csv`
- `lcd_report.json`
- `ppm_validate.txt`
- `README.txt`

Snapshot `README.txt` metadata includes:
- host
- renderer backend
- font config digest (`assets/config/init.lua`)
- project config digest (`.zide.lua`, or `missing`)

Retention guidance:

- Keep at least the latest 5 snapshot folders.
- If snapshots accumulate, remove the oldest after preserving any milestone
  snapshot referenced by `docs/todo/ui/font_rendering.md`.
