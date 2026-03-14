import { escapeHtml, repoRelative } from "./utils.js";
import { syncActiveLink } from "./tree.js";
import { renderMermaidBlocks } from "./mermaid.js";

export async function loadDoc({
  path,
  marked,
  mermaid,
  rootEl,
  viewerEl,
  titleEl,
  subtitleEl,
  rawLinkEl,
  docs,
  defaultDocPath,
}) {
  titleEl.textContent = path;
  subtitleEl.textContent = "";
  rawLinkEl.href = repoRelative(path);
  viewerEl.innerHTML = `<p class="status">Loading ${escapeHtml(path)}...</p>`;
  syncActiveLink(docs, defaultDocPath);

  try {
    const res = await fetch(repoRelative(path));
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const source = await res.text();
        const html = marked.parse(source);
        viewerEl.innerHTML = html;
        subtitleEl.textContent = "";
        await renderMermaidBlocks(mermaid, rootEl, viewerEl);
  } catch (err) {
    viewerEl.innerHTML = `
      <div class="callout">
        Failed to load <code>${escapeHtml(path)}</code>.
      </div>
      <p>This viewer fetches Markdown files over HTTP. Open this directory through the local launcher:</p>
      <pre><code>cd /home/home/personal/zide/tools/docs_explorer
python3 docs_explorer.py</code></pre>
      <p>Error: <code>${escapeHtml(String(err))}</code></p>
    `;
    subtitleEl.textContent = "";
  }
}
