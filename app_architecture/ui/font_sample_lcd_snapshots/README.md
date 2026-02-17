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

Per snapshot folder (`YYYY-MM-DD`), the expected files are:

- `lcd_report.txt`
- `lcd_report.csv`
- `lcd_report.json`
- `ppm_validate.txt`
- `README.txt`
