import { renderMarkdown } from "./markdown.js";
import { repoRelative } from "../shared/utils.js";
import { syncActiveLink } from "../tree/tree.js";
import { renderMermaidBlocks } from "./mermaid.js";
import {
  renderViewer,
  setViewerContent,
  setViewerError,
  setViewerLoading,
} from "./viewer_state.js";
import type { AppState } from "../shared/types.js";
import type { MarkedApi, MermaidApi } from "../shared/vendor_types.js";

function renderViewerLoading(state: AppState, viewerEl: HTMLElement, path: string): void {
  setViewerLoading(state, path);
  renderViewer(state, viewerEl);
}

function renderViewerContent(state: AppState, viewerEl: HTMLElement, html: string): void {
  setViewerContent(state, html);
  renderViewer(state, viewerEl);
}

function renderViewerFailure(
  state: AppState,
  viewerEl: HTMLElement,
  path: string,
  err: unknown,
): void {
  setViewerError(state, path, err);
  renderViewer(state, viewerEl);
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
  renderViewerLoading(state, viewerEl, path);
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
    renderViewerContent(state, viewerEl, html);
    onReady(state, path);
    await renderMermaidBlocks(mermaid, rootEl, viewerEl);
  } catch (err) {
    onError(state, path);
    renderViewerFailure(state, viewerEl, path, err);
  }
}
