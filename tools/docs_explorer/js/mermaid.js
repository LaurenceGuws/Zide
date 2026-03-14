import { currentTheme, themeVariables } from "./theme.js";
import { escapeHtml } from "./utils.js";

export function initMermaidForTheme(mermaid, rootEl, theme) {
  mermaid.initialize({
    startOnLoad: false,
    theme: "base",
    themeVariables: themeVariables(rootEl, theme),
  });
}

export async function renderMermaidBlocks(mermaid, rootEl, viewerEl) {
  const blocks = viewerEl.querySelectorAll("pre > code.language-mermaid");
  let idx = 0;
  for (const code of blocks) {
    const pre = code.parentElement;
    const graph = code.textContent;
    const host = document.createElement("div");
    host.className = "mermaid";
    host.dataset.graph = graph;
    const id = `mermaid-${Date.now()}-${idx++}`;
    try {
      const { svg } = await mermaid.render(id, graph);
      host.innerHTML = svg;
    } catch (err) {
      host.innerHTML = `<pre>${escapeHtml(String(err))}</pre>`;
    }
    pre.replaceWith(host);
  }
}

export async function rerenderVisibleMermaid(mermaid, rootEl, viewerEl) {
  const blocks = viewerEl.querySelectorAll(".mermaid[data-graph]");
  if (blocks.length === 0) return;
  initMermaidForTheme(mermaid, rootEl, currentTheme(rootEl));
  let idx = 0;
  for (const host of blocks) {
    const graph = host.dataset.graph || "";
    const id = `mermaid-rerender-${Date.now()}-${idx++}`;
    try {
      const { svg } = await mermaid.render(id, graph);
      host.innerHTML = svg;
    } catch (err) {
      host.innerHTML = `<pre>${escapeHtml(String(err))}</pre>`;
    }
  }
}
