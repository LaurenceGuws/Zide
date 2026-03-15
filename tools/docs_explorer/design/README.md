# Docs Explorer Design

This folder is the explorer's small in-repo design authority.

Use it the same way Zide uses `app_architecture/`:

- current widget/system design lives here
- active implementation follow-up lives in [../TODO.md](/home/home/personal/zide/tools/docs_explorer/TODO.md)
- high-level contributor entrypoints stay in:
  - [../README.md](/home/home/personal/zide/tools/docs_explorer/README.md)
  - [../ARCHITECTURE.md](/home/home/personal/zide/tools/docs_explorer/ARCHITECTURE.md)

Current design docs:

- [TREE_WIDGET.md](/home/home/personal/zide/tools/docs_explorer/design/TREE_WIDGET.md)
  - tree geometry
  - active-path highlighting
  - connector ownership

Rules:

- keep this folder focused on current design, not progress logs
- if a UI seam becomes non-trivial enough to need diagrams, contracts, or
  invariants, give it a focused design doc here
- move implementation status and unfinished steps back into
  [../TODO.md](/home/home/personal/zide/tools/docs_explorer/TODO.md)
