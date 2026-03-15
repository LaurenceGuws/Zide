# Docs Explorer

Local browser-based docs explorer for Zide's `docs/` and
`app_architecture/` content.

Hosted release/docs entrypoint:

- <https://laurenceguws.github.io/Zide/tools/docs_explorer/>

Current entrypoints:

- `docs_explorer.py`: lightweight local HTTP launcher
- `index.html`: HTML shell
- `styles/base.css`: stylesheet import root
- `ts/`: TypeScript source modules
  - `docs/`: document routing/rendering/view state
  - `tree/`: tree rendering and tree state
  - `theme/`: theme/runtime palette wiring
  - `shell/`: app-shell bootstrap, DOM lookup, and icon wiring
  - `shared/`: shared types/helpers/vendor declarations
- `build/js/`: generated browser ESM output
- `config/project.json`: project-specific metadata
- `config/project.pages.json`: alternate hosted/pages metadata
- `config/docs-index.json`: repo doc index

Run:

```bash
cd /home/home/personal/zide
npm run build:docs-explorer

cd /home/home/personal/zide/tools/docs_explorer
python3 docs_explorer.py
```

Then open the printed URL.

Alternate config:

```bash
cd /home/home/personal/zide/tools/docs_explorer
python3 docs_explorer.py 8000 project.pages.json
```

You can also select config directly in the browser:

```text
http://127.0.0.1:8000/tools/docs_explorer/?config=project.pages.json
```

Structure is intentionally small and framework-free so the tool can be reused
across other repos later by swapping project config and doc-index JSON.

Current shell rule:

- the outer shell owns the atmospheric background field
- panes own the main material layers
- small wrappers and controls should prefer transparency, border, and hover
  state before adding their own local fill
- theme/config should drive the surface system through tokens rather than
  scattered component-specific color formulas

Theme rule:

- project config may override the base palette only
- derived shell/control/viewer materials stay in `styles/theme.css`
- if a visual change can be expressed by changing a derived token, prefer that
  over adding a new component-local background

Notes:

- `ts/` is the source tree.
- `build/js/` is generated output and is intentionally not checked in.
- The mapping is direct: files under `ts/` compile to browser ESM under
  `build/js/`, preserving the same subtree layout.
- The launcher expects `build/js/main.js` to exist and will tell you to run the
  build step if it is missing.
- `main` stays source-only for this tool.
- If GitHub Pages is published for a release, built explorer assets may be
  committed on the release branch as part of the release ritual instead of on
  `main`.
- Release-branch Pages publication should keep `.nojekyll` at the repo root so
  GitHub serves the static explorer directly.
