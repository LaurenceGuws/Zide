Date: 2026-03-11

Purpose: make it cheap to turn a real terminal redraw repro into a replay-backed
authority once the current in-tree sample set is exhausted.

## When To Use This

Use this when:

- manual `nvim` / TUI behavior still looks wrong
- the current replay fixtures no longer expose the problem
- we need a fresh real non-clear reproducer before changing publication logic

Do not use this to invent synthetic targets when an existing replay fixture is
already authoritative.

## Capture Shape

For redraw/publication work, prefer a `harness_api` fixture:

- `baseline_input`
- one or more `output_chunks`

This is better than mixing everything into one `.vt` stream because:

- we can acknowledge a presented baseline cleanly
- we can model multi-packet redraws honestly
- we can assert damage only on the update phase

## Tool

Use:

- [terminal_make_redraw_fixture.py](/home/home/personal/zide/tools/terminal_make_redraw_fixture.py)
- [terminal_capture_pty.py](/home/home/personal/zide/tools/terminal_capture_pty.py)
- [terminal_capture_redraw_fixture.py](/home/home/personal/zide/tools/terminal_capture_redraw_fixture.py)

Capture raw PTY output first:

```bash
python3 tools/terminal_capture_pty.py \
  --output-file /tmp/nvim-baseline.txt \
  -- -- nvim
```

For scripted input or a second update phase:

```bash
python3 tools/terminal_capture_pty.py \
  --output-file /tmp/nvim-update-1.txt \
  --stdin-file /tmp/nvim-keys-1.txt \
  -- -- nvim
```

Then turn those captures into a harness-api fixture:

Example:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --name redraw_nvim_real_sample \
  --rows 40 \
  --cols 120 \
  --baseline-file /tmp/nvim-baseline.txt \
  --update-file /tmp/nvim-update-1.txt \
  --update-file /tmp/nvim-update-2.txt
```

That writes:

- `fixtures/terminal/redraw_nvim_real_sample.json`
- `fixtures/terminal/redraw_nvim_real_sample.vt`

Without an observed-state file, the tool leaves `expected_damage` as a
placeholder. Fill it in from the observed current backend behavior first, then
update the golden.

To record the current observed publication contract for a fixture:

```bash
zig build test-terminal-replay -- \
  --fixture redraw_nvim_real_sample \
  --observed-file zig-cache/terminal-replay/redraw_nvim_real_sample.observed.json
```

That writes a clean JSON record of:

- `dirty`
- `damage`
- `viewport_shift_rows`
- `viewport_shift_exposed_only`

Use that file to fill the fixture's `expected_dirty`, `expected_damage`, and
viewport-shift assertions before updating goldens.

You can also feed the observed JSON back into the fixture generator directly:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --manifest-file /tmp/zide-redraw-captures/redraw_nvim_real_sample/manifest.json \
  --observed-file zig-cache/terminal-replay/redraw_nvim_real_sample.observed.json
```

That rewrites the fixture with the observed redraw contract populated.

If you already have a staged capture manifest, rebuild from it directly:

```bash
python3 tools/terminal_make_redraw_fixture.py \
  --manifest-file /tmp/zide-redraw-captures/redraw_nvim_real_sample/manifest.json
```

That reuses the captured baseline/update files recorded in the manifest instead
of retyping the fixture inputs.

Or use the staged wrapper:

```bash
python3 tools/terminal_capture_redraw_fixture.py \
  --name redraw_nvim_real_sample \
  --rows 40 \
  --cols 120 \
  --cwd /path/to/project \
  --no-stdout \
  --hydrate-observed \
  --baseline-shell 'nvim' \
  --update-shell 'nvim'
```

That:

- records the baseline capture
- records each update capture
- writes the harness-api fixture skeleton
- optionally runs the replay runner and writes the observed redraw contract back into the fixture
- keeps intermediate capture files under `/tmp/zide-redraw-captures/<name>/`
- writes a `manifest.json` beside those captures so the exact command/cwd/input recipe stays attached to the reproducer
- is the preferred path when capturing a fresh live `nvim`/TUI redraw repro

Useful options:

- `--cwd` to run every capture phase in the same project directory
- `--no-stdout` to keep capture quiet while still recording raw PTY bytes
- `--baseline-stdin-file` / `--update-stdin-file` for scripted keystroke phases
- `--hydrate-observed` to run replay immediately and fill `expected_dirty`, `expected_damage`, and viewport-shift assertions from the current backend output

Current limitation:

- `--hydrate-observed` currently requires `--fixture-dir fixtures/terminal`, because the replay build step only discovers fixtures from the repo fixture root.

## Authoring Rules

1. Keep the fixture real.
   Use captured terminal bytes from an actual TUI state transition, ideally from
   `terminal_capture_pty.py`.

2. Keep the viewport small enough to inspect.
   Trim rows/cols to the smallest viewport that still reproduces the bug.

3. Preserve packet boundaries when they matter.
   If the bad publication only appears across multiple writes, keep separate
   `--update-file` chunks.

4. Capture current behavior before fixing it.
   The replay fixture must first lock what the backend actually does today.

5. Only then change publication logic.

## Validation

After filling in `expected_damage`, run:

```bash
zig build test-terminal-replay -- --fixture <name> --update-goldens
zig build test-terminal-replay -- --fixture <name>
```

Then run the broader local validation set before committing the behavior change.
