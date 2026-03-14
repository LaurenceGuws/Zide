import { escapeHtml } from "./utils.js";
import { setViewerHtml } from "./state.js";

/** @param {import("./types.js").AppState} state
 *  @param {string} path
 */
export function setViewerLoading(state, path) {
  setViewerHtml(state, `<p class="status">Loading ${escapeHtml(path)}...</p>`);
}

/** @param {import("./types.js").AppState} state
 *  @param {string} html
 */
export function setViewerContent(state, html) {
  setViewerHtml(state, html);
}

/** @param {import("./types.js").AppState} state
 *  @param {string} path
 *  @param {unknown} err
 */
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

/** @param {import("./types.js").AppState} state
 *  @param {HTMLElement} viewerEl
 */
export function renderViewer(state, viewerEl) {
  viewerEl.innerHTML = state.viewer.html;
}
