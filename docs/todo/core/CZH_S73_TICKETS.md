# CZH-S73 Tickets - Product Path Hygiene Baseline

Sprint: `CZH-S73`
Batch: `CZH-B78`
Gate: `CZH-GATE-132`
Focus: remove investigation logging/probe/debug residue and avoidable copy churn from real app paths so performance baselines are meaningful.

## Execution Rules

- Code/test movement is mandatory for every ticket except explicitly labelled `doc-only` tickets.
- No documentation-only implementation commits.
- Documentation updates may only record what changed in code/tests.
- No behavior or ABI changes unless a ticket finds a correctness bug and records it as such.
- Keep naming cleanup limited to symbols touched by the hygiene cut; broader naming/topology normalization is the next phase.

## Tickets

### `CZH-1229` Hot-path hygiene audit map

Scope: audit real app execution paths for investigation logging, debug capture writes, raw pointer telemetry, and avoidable copy churn.

Required output:
- a concrete source-file map with each finding classified as remove, gate, keep-as-correctness, keep-as-operator-telemetry, or defer
- at least one directly executable code/test cleanup ticket identified from the audit

Acceptance:
- names concrete files/functions, not broad subsystems
- separates product paths from tests/debug-only helpers
- does not expand into naming/topology phase work

Architect result:
- Accepted with the finding that no executable hygiene cleanup targets were identified from code inspection alone.
- Output authority: `docs/todo/core/CZH_1229_HOT_PATH_HYGIENE_AUDIT.md`.

### `CZH-1230` Measurement attribution baseline (`doc-only`, architect-approved)

Scope: produce bounded performance attribution for the audited hot paths to identify one concrete, defensible cleanup target.

Acceptance:
- records measured hotspot evidence with file/function attribution
- identifies one concrete artifact suitable for code cleanup in `CZH-1231`
- does not invent cleanup targets without measurement evidence

Architect result:
- Accepted with the finding that no concrete cleanup target is defensible from current hygiene scope.
- Output authority: `docs/todo/core/CZH_1230_MEASUREMENT_RESULTS.md`.

### `CZH-1231` First measured hot-path cleanup cut

Scope: execute one bounded code cleanup from `CZH-1230` measured evidence.

Acceptance:
- code/test movement required
- preserves product behavior and ABI
- no broad widget module moves

### `CZH-1232` Second measured cleanup or editor/runtime cut

Scope: execute a second bounded cleanup from measured evidence, preferably in editor/runtime if justified by attribution.

Acceptance:
- code/test movement required
- keeps useful operator telemetry only if disabled cost and payload are defensible
- no unrelated feature work

### `CZH-1233` Regression locks for removed probes

Scope: replace reliance on removed logs/probes with tests or explicit assertions where a correctness invariant still matters.

Acceptance:
- adds or updates executable checks for at least one cleaned path
- does not recreate product-path debug capture as a test substitute

### `CZH-1234` Product hygiene validation packet

Scope: run the validation ladder and record only the final evidence needed to close `CZH-B78`.

Acceptance:
- records validation results in `docs/todo/core/implementation.md`
- updates `JIRA_BOARD.md` to `review_gate`
- does not mark Architect acceptance

## Architect closure

- `CZH-S73` is accepted as a baseline-completion sprint for phase-1 hygiene.
- `CZH-1231`..`CZH-1234` are not executed in this sprint because audit + measurement found no executable hygiene cleanup targets.
- Next active sprint: `CZH-S74` (`CZH-B79`) for phase-2 naming and module-topology normalization.
