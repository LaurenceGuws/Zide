# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: Android terminal excellence
- Campaign: Android post-refocus correctness/perf hardening
- Current milestone: `AX-M1+AX-M2` (`in_progress`, macro batch review at `AX-M2`)
- Active queue authority: `docs/todo/android/implementation.md`
- Engineer entrypoint (dual mode): `docs/todo/android/ENGINEER_ENTRYPOINT.md`

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
