# Docs Explorer

Local browser-based docs explorer for Zide's `docs/` and
`app_architecture/` content.

Current entrypoints:

- `docs_explorer.py`: lightweight local HTTP launcher
- `index.html`: HTML shell
- `styles/base.css`: shared styling + theme tokens
- `js/`: client-side modules
- `config/project.json`: project-specific metadata
- `config/docs-index.json`: repo doc index

Run:

```bash
cd /home/home/personal/zide/tools/docs_explorer
python3 docs_explorer.py
```

Then open the printed URL.

Structure is intentionally small and framework-free so the tool can be reused
across other repos later by swapping project config and doc-index JSON.
