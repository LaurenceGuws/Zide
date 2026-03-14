import { repoRelative } from "./utils.js";
import { syncActiveLink } from "./tree.js";
import { renderMermaidBlocks } from "./mermaid.js";
import { renderViewer, setViewerContent, setViewerError, setViewerLoading } from "./viewer_state.js";

export async function loadDoc({
  state,
  path,
  marked,
  mermaid,
  rootEl,
  viewerEl,
  docs,
  defaultDocPath,
  onLoading,
  onReady,
  onError,
}) {
  onLoading(state, path);
  setViewerLoading(state, path);
  renderViewer(state, viewerEl);
  syncActiveLink(state.tree.activePath);

  try {
    const res = await fetch(repoRelative(path));
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const source = await res.text();
    const html = marked.parse(source);
    setViewerContent(state, html);
    renderViewer(state, viewerEl);
    onReady(state, path);
    await renderMermaidBlocks(mermaid, rootEl, viewerEl);
  } catch (err) {
    onError(state, path);
    setViewerError(state, path, err);
    renderViewer(state, viewerEl);
  }
}
