# Docs Explorer

Local browser-based docs explorer for Zide's `docs/` and
`app_architecture/` content.

Current entrypoints:

- `docs_explorer.py`: lightweight local HTTP launcher
- `index.html`: HTML shell
- `styles/base.css`: stylesheet import root
- `js/`: TypeScript source modules
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

Notes:

- `build/js/` is generated output and is intentionally not checked in.
- The launcher expects `build/js/main.js` to exist and will tell you to run the
  build step if it is missing.
