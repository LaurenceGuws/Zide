import { renderMarkdown } from "./markdown.js";
<<<<<<< HEAD:tools/docs_explorer/js/viewer.ts
import { repoRelative } from "./utils.js";
import { syncActiveLink } from "./tree.js";
=======
import { currentFindFromHash, repoRelative } from "../shared/utils.js";
import { syncActiveLink } from "../tree/tree.js";
>>>>>>> cba2f82 (Add docs explorer ripgrep search):tools/docs_explorer/ts/docs/viewer.ts
import { renderMermaidBlocks } from "./mermaid.js";
import {
  renderViewer,
  setViewerContent,
  setViewerError,
  setViewerLoading,
} from "./viewer_state.js";
import type { AppState } from "./types.js";
import type { MarkedApi, MermaidApi } from "./vendor_types.js";

function focusSearchHit(viewerEl: HTMLElement, term: string): void {
  const query = term.trim();
  if (!query) return;

  const walker = document.createTreeWalker(viewerEl, NodeFilter.SHOW_TEXT);
  const lowerQuery = query.toLowerCase();
  while (walker.nextNode()) {
    const node = walker.currentNode;
    if (!(node instanceof Text)) continue;
    const value = node.textContent ?? "";
    const index = value.toLowerCase().indexOf(lowerQuery);
    if (index < 0) continue;
    const range = document.createRange();
    range.setStart(node, index);
    range.setEnd(node, index + query.length);
    const mark = document.createElement("mark");
    mark.className = "viewer-search-hit";
    try {
      range.surroundContents(mark);
    } catch {
      mark.textContent = value.slice(index, index + query.length);
      range.deleteContents();
      range.insertNode(mark);
    }
    mark.scrollIntoView({ block: "center", behavior: "smooth" });
    return;
  }
}

export async function loadDoc(args: {
  state: AppState;
  repoBasePath: string;
  repoAbsolutePath?: string;
  path: string | null;
  marked: MarkedApi;
  mermaid: MermaidApi;
  rootEl: HTMLElement;
  viewerEl: HTMLElement;
  docs: string[];
  defaultDocPath: string;
  onLoading: (state: AppState, path: string) => void;
  onReady: (state: AppState, path: string) => void;
  onError: (state: AppState, path: string) => void;
}): Promise<void> {
  const {
    state,
    repoBasePath,
    repoAbsolutePath,
    path,
    marked,
    mermaid,
    rootEl,
    viewerEl,
    docs,
    onLoading,
    onReady,
    onError,
  } = args;

  if (!path) return;

  onLoading(state, path);
  setViewerLoading(state, path);
  renderViewer(state, viewerEl);
  syncActiveLink(state.tree.activePath);

  try {
    const res = await fetch(repoRelative(repoBasePath, path));
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const source = await res.text();
    const html = renderMarkdown(
      marked,
      source,
      path,
      repoBasePath,
      docs,
      repoAbsolutePath,
    );
    setViewerContent(state, html);
    renderViewer(state, viewerEl);
    onReady(state, path);
    await renderMermaidBlocks(mermaid, rootEl, viewerEl);
    focusSearchHit(viewerEl, currentFindFromHash());
  } catch (err) {
    onError(state, path);
    setViewerError(state, path, err);
    renderViewer(state, viewerEl);
  }
}
