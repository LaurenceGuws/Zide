# Terminal Ligatures TODO

## Scope

Add first-class terminal ligature support without breaking monospace grid correctness.

## Constraints

- Preserve terminal cell width invariants.
- Do not regress combining marks, emoji ZWJ, or fallback font boundaries.
- Keep run splitting deterministic around style and cursor boundaries.
- Keep config, shaping, and fixture changes reviewable as separate steps.

## TODO

### Phase 0 Behavior Contract

- [ ] `TL-0-01` Write the ligature behavior contract and parity notes

### Phase 1 Config Surface

- [x] `TL-1-01` Add terminal `disable_ligatures` strategy
- [x] `TL-1-02` Add terminal `font_features` override

### Phase 2 Shaping Pipeline

- [x] `TL-2-01` Refactor run shaping to accept feature policy
- [x] `TL-2-02` Implement cursor-aware run splitting
- [x] `TL-2-03` Preserve style boundaries while ligatures are enabled

### Phase 3 Rendering and Interaction Correctness

- [ ] `TL-3-01` Map ligature clusters to cells deterministically
- [ ] `TL-3-02` Audit clipboard and selection behavior for ligature runs

### Phase 4 Fixtures, Perf, and Rollout

- [ ] `TL-4-01` Add ligature fixture strings and screenshots
- [ ] `TL-4-02` Add a terminal replay and smoke verification checklist
- [ ] `TL-4-03` Benchmark run-shaping overhead with ligatures enabled

