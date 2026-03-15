# Tree Widget Design

## Goal

Make the docs tree read like a deliberate hierarchy widget rather than a loose
list of folders with decorative rails.

The target visual reference is closer to a terminal/process tree:

- each row owns its own connector geometry
- vertical rails read as continuity between rows
- horizontal elbows read as explicit joins into child rows
- active path highlighting follows the actual branch path instead of painting
  whole containers

## Current Direction

The current implementation is in transition.

What is already true:

- the tree is rendered from explicit state
- folders/files are rendered from a tree model, not from ad hoc DOM mutation
- active path and expanded paths are explicit state
- connector and hover colors are token-driven through
  [theme.css](/home/home/personal/zide/tools/docs_explorer/styles/theme.css)

What is still weak:

- connector geometry is still partly container-owned instead of row-owned
- active-path highlighting still depends on branch-height approximation
- elbows and vertical stems are not yet derived from a single row model
- open-folder handoff is easy to regress if it adds a second continuation layer
  outside the row-owned connector path

## Desired Geometry Model

The clean model is:

1. each child row owns its elbow
2. each row can optionally paint:
   - incoming vertical continuation
   - horizontal elbow
   - outgoing vertical continuation
3. active path is just a class on the exact rows in the path
4. parent containers should not need to guess stem height to the active child

That means the long-term design should avoid:

- one full-height active rail per open container
- pseudo-elements that try to stop at a guessed child index
- separate geometry rules for folders vs files
- summary-level or container-level open-folder continuation patches that
  duplicate the row-owned connector path

## Ownership

Design ownership is split like this:

- [tree_model.ts](/home/home/personal/zide/tools/docs_explorer/ts/tree/tree_model.ts)
  - structural tree model from document paths
- [tree_markup.ts](/home/home/personal/zide/tools/docs_explorer/ts/tree/tree_markup.ts)
  - row semantics and row/path classes
- [tree.ts](/home/home/personal/zide/tools/docs_explorer/ts/tree/tree.ts)
  - DOM mount and toggle wiring
- [tree.css](/home/home/personal/zide/tools/docs_explorer/styles/tree.css)
  - row geometry and connector visuals
- [theme.css](/home/home/personal/zide/tools/docs_explorer/styles/theme.css)
  - connector and active-path tokens

## Invariants

- folders and files should participate in one connector system
- active-path highlighting should be row-local, not container-guessed
- inactive branches should stay readable but subdued
- tree visuals should remain token-driven and theme-safe
- markup should carry semantic classes/data for path state; CSS should not infer
  active-path structure indirectly

## Follow-up

The next implementation step should replace the current active-stem
approximation with true row-owned connector segments.

The next open-folder iteration should be designed first and keep one connector
grammar:

1. folder/file rows own elbows and stems
2. open state may change the elbow glyph/shape
3. open state must not add a second active continuation layer on `summary` or
   on `.folder-children`

Track that work in [../TODO.md](/home/home/personal/zide/tools/docs_explorer/TODO.md).
