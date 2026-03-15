# Renderer TODO

## Scope

Renderer modularization and OS abstraction boundaries, with Linux SDL3 plus OpenGL as the stable baseline and Windows prep kept behind clear seams.

## Constraints

- Extraction-only refactors unless explicitly re-scoped.
- Keep OS window and input boundaries clear from renderer backend code.
- Preserve widget behavior and keep diffs reviewable.
- Run manual smoke checks after extraction steps.

## Entry Points

- `src/ui/renderer.zig`
- `src/app_shell.zig`
- `src/main.zig`

## Status

- [x] Extraction phase complete
- [x] `zig build` check passed on 2026-01-31

## Boundary Map

```mermaid
flowchart LR
    App["App shell / window host"] --> Renderer["Renderer facade"]
    Renderer --> GL["OpenGL submission + scene/state"]
    Renderer --> Widgets["Widget draw surfaces"]
    Renderer --> Text["Font/text helpers"]

    App -. window/input lifecycle .-> Renderer
    Renderer -. must not own app/terminal policy .-> App
```

## Extraction Trigger

```mermaid
flowchart TD
    Block["renderer block under review"] --> Q1{"one responsibility?"}
    Q1 -- yes --> Keep["keep in current owner"]
    Q1 -- no --> Q2{"crosses platform vs renderer boundary?"}
    Q2 -- yes --> Extract["extract to focused sub-owner"]
    Q2 -- no --> Q3{"just residue micro-file churn?"}
    Q3 -- yes --> Collapse["collapse back into stronger owner"]
    Q3 -- no --> Keep
```

## Remaining Work

- [ ] Only extract when a renderer block exceeds one responsibility or crosses platform and renderer boundaries.
- [ ] Add focused tests once replay harness authority exists.
- [ ] Revisit Windows smoke-build dependencies when the `vcpkg` environment is ready.
