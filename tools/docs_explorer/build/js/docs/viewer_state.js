import { escapeHtml } from "../shared/utils.js";
import { setViewerHtml } from "../state.js";
export function setViewerLoading(state, path) {
    setViewerHtml(state, `<p class="status">Loading ${escapeHtml(path)}...</p>`);
}
export function setViewerContent(state, html) {
    setViewerHtml(state, html);
}
export function setViewerError(state, path, err) {
    setViewerHtml(state, `
    <div class="callout">
      Failed to load <code>${escapeHtml(path)}</code>.
    </div>
    <p>This viewer fetches Markdown files over HTTP. Open this directory through the local launcher:</p>
    <pre><code>cd /home/home/personal/zide/tools/docs_explorer
python3 docs_explorer.py</code></pre>
    <p>Error: <code>${escapeHtml(String(err))}</code></p>
  `);
}
export function renderViewer(state, viewerEl) {
    viewerEl.innerHTML = state.viewer.html;
}
