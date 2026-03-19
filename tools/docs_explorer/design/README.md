# Docs Explorer Design

This folder is the explorer's small in-repo design authority.

Use it the same way Zide uses `app_architecture/`:

- current widget/system design lives here
- active implementation follow-up lives in [../TODO.md](../TODO.md)
- high-level contributor entrypoints stay in:
  - [../README.md](../README.md)
  - [../ARCHITECTURE.md](../ARCHITECTURE.md)

Current design docs:

- [TREE_WIDGET.md](TREE_WIDGET.md)
  - tree geometry
  - active-path highlighting
  - connector ownership

Rules:

- keep this folder focused on current design, not progress logs
- if a UI seam becomes non-trivial enough to need diagrams, contracts, or
  invariants, give it a focused design doc here
- move implementation status and unfinished steps back into
  [../TODO.md](../TODO.md)
