import { currentTheme, themeVariables } from "../theme/theme.js";
import { escapeHtml } from "../shared/utils.js";
import type { ThemeName } from "../shared/types.js";
import type { MermaidApi } from "../shared/vendor_types.js";

export function initMermaidForTheme(
  mermaid: MermaidApi,
  rootEl: HTMLElement,
  theme: ThemeName,
): void {
  mermaid.initialize({
    startOnLoad: false,
    theme: "base",
    themeVariables: themeVariables(rootEl, theme),
  });
}

export async function renderMermaidBlocks(
  mermaid: MermaidApi,
  rootEl: HTMLElement,
  viewerEl: HTMLElement,
): Promise<void> {
  const blocks = Array.from(
    viewerEl.querySelectorAll<HTMLElement>("pre > code.language-mermaid"),
  );
  let idx = 0;
  for (const code of blocks) {
    const pre = code.parentElement;
    if (!pre) continue;
    const graph = code.textContent || "";
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

export async function rerenderVisibleMermaid(
  mermaid: MermaidApi,
  rootEl: HTMLElement,
  viewerEl: HTMLElement,
): Promise<void> {
  const blocks = Array.from(
    viewerEl.querySelectorAll<HTMLElement>(".mermaid[data-graph]"),
  );
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
