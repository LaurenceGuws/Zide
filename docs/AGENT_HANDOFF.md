# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: **Android stabilization follow-through** (`ASF`) — follows post-refocus / AX matrix work; targets operator-verified closure of remaining RF_M5 matrix gaps (IME/assist, touch gestures).
- Current milestone: `ASF-M3` (`in_progress`, campaign closeout or escalation)
- Prior closed: `ASF-M2` (matrix verdicts: IME/gesture **blocked** pending operator evidence); `ASF-M1`; `AX-M5`; `AX-M4`
- Active queue authority: `docs/todo/android/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/android/ENGINEER_ENTRYPOINT.md`

## Dual Session Startup (Copy/Paste)

Architect session seed:

- Read `docs/todo/android/implementation.md` first.
- Confirm the milestone marked `in_progress`.
- Define the next bounded engineer batch from that milestone only.
- Publish an engineer prompt that uses the response contract and stop rules in
  `docs/todo/android/ENGINEER_ENTRYPOINT.md`.

Engineer session seed:

- Read `docs/todo/android/ENGINEER_ENTRYPOINT.md`, then
  `docs/todo/android/implementation.md`, then this handoff file.
- Execute only the milestone marked `in_progress` in
  `docs/todo/android/implementation.md`.
- Stop only on blocker or milestone gate; report using required headers.

## First Read Order

1. `docs/todo/android/implementation.md`
2. `docs/todo/android/RF_M5_STABILIZATION_MATRIX.md`
3. `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
4. `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`

## Execution Contract

- Follow only the active milestone `Queue line (exact)` from the Android queue.
- Keep cuts scoped; compile every cut; run deploy + `AndroidRuntime:E` smoke at
  seam boundaries.
- Compile gate is strict: `:app:compileDebugJavaWithJavac` and
  `:app:compileReleaseJavaWithJavac` both must stay green under warnings-as-errors.
- Update docs in the same wave.
- Architect updates use: `Blocked by humain review needed: true|false`.
- Engineer updates use: `Blocked by Archtect review needed: true|false`.

## Historical Notes

Pre-refocus Android task logs were archived to:

- `docs/review/ANDROID_LANE_HISTORY_2026-04-17.md`
