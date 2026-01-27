# Agent Workflow (Zide)

## About the App

Zide aims to implement an IDE fully in Zig to the furthest extent possible that makes sense for our goals. The goal is a modern IDE for revamped workspace and micro-service development. A key driver: opening many microservices in a single workspace (e.g., 8 Java LSPs) can consume ~16GB RAM and slow everything down.

We design every piece with embedded-style resource constraints in mind. That means aggressive caching, smart lifecycle management for tooling (e.g., spin up LSPs, cache results, hot-reload only edited blocks/references, then shut them down), and a strong focus on raw responsiveness and performance.

Follow this workflow for every feature/task:

1. Read `docs/AGENT_HANDOFF.md`.
2. Use the handoff to confirm current focus and constraints.
3. Read the current todo file(s), reference implementations, and Zide's current implementation to learn best practices and feature-specific guidance.
4. Implement the feature.
5. Update all relevant docs to reflect changes and progress.
6. Inform the user how to test changes and debug until approved.
7. Do NOT commit until the user has run the tests and explicitly approved (e.g., "nice" or "it's working").
8. Keep diffs small and reviewable; no file moves before baseline tests exist.
9. No behavior changes during extraction-only refactors; any semantic change must be separately scoped and test-driven.
10. Extraction-only constraint: no renaming of public symbols, no logic changes, no behavior-motivated simplifications, no "while we're here" cleanups.
11. Before any refactor, implement the replay harness, capture baseline goldens, and lock the fixture list as regression authority.
12. No commits (including tests/harness) until the user approves after running the tests.
13. Once approved, commit each step labeled as the step header.
14. Return to the todo and suggest 3 next changes.

## Doc scope policy

- `docs/AGENT_HANDOFF.md` and `docs/AGENT_HOVER.md` are **high-level only**: focus, constraints, and entrypoint pointers for a fresh session.
- All task progress, checkpoints, and detailed changes live in the relevant todo files and `app_architecture/` docs.
- If research was done to create or update a todo item, capture it in the relevant `app_architecture/` doc (not in handoff).
- See `docs/WORKFLOW.md` for the full workflow + docs usage guide.
