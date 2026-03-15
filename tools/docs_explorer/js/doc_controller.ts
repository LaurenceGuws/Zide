import { rerenderVisibleMermaid } from "./mermaid.js";
import { renderHighlightedCode } from "./highlight.js";
import { currentDocFromHash } from "./utils.js";
import { setCurrentDoc, setSearchQuery } from "./state.js";
import {
  renderTreeFromState,
  updateTreeActivePath,
  updateTreeExpandedPaths,
  updateTreeFilter,
} from "./tree_state.js";
import {
  renderDocumentChrome,
  setDocumentError,
  setDocumentLoading,
  setDocumentReady,
} from "./view_state.js";
import { loadDoc } from "./viewer.js";
import type { AppShell, AppState } from "./types.js";
import type { HighlightJsApi, MarkedApi, MermaidApi } from "./vendor_types.js";

export function createDocController(args: {
  state: AppState;
  shell: AppShell;
  appIconPath: string;
  repoBasePath: string;
  repoAbsolutePath?: string;
  docs: string[];
  defaultDocPath: string;
  treeEl: HTMLElement;
  viewerEl: HTMLElement;
  searchEl: HTMLInputElement;
  marked: MarkedApi;
  mermaid: MermaidApi;
  hljs?: HighlightJsApi;
  rootEl: HTMLElement;
}) {
  const {
    state,
    shell,
    appIconPath,
    repoBasePath,
    repoAbsolutePath,
    docs,
    defaultDocPath,
    treeEl,
    viewerEl,
    searchEl,
    marked,
    mermaid,
    hljs,
    rootEl,
  } = args;

  async function renderCurrentDoc(): Promise<void> {
    const currentPath = currentDocFromHash(docs, defaultDocPath);
    setCurrentDoc(state, currentPath);
    updateTreeActivePath(state, currentPath);
    renderTree();
    await loadDoc({
      state,
      repoBasePath,
      repoAbsolutePath,
      path: state.currentDoc,
      marked,
      mermaid,
      rootEl,
      viewerEl,
      docs,
      defaultDocPath,
      onLoading(nextState: AppState, path: string) {
        setDocumentLoading(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell, appIconPath);
      },
      onReady(nextState: AppState, path: string) {
        setDocumentReady(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell, appIconPath);
        renderHighlightedCode(hljs, viewerEl);
      },
      onError(nextState: AppState, path: string) {
        setDocumentError(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell, appIconPath);
      },
    });
  }

  function renderTree(): void {
    renderTreeFromState(state, treeEl, docs, (expandedPaths) => {
      updateTreeExpandedPaths(state, expandedPaths);
    });
  }

  function applySearchQuery(query: string): void {
    setSearchQuery(state, query);
    updateTreeFilter(state, query);
    renderTree();
  }

  function install(): void {
    searchEl.addEventListener("input", () => {
      applySearchQuery(searchEl.value);
    });

    window.addEventListener("hashchange", () => {
      void renderCurrentDoc();
    });
  }

  async function rerenderDiagramsForTheme(): Promise<void> {
    await rerenderVisibleMermaid(mermaid, rootEl, viewerEl);
  }

  return {
    install,
    renderTree,
    renderCurrentDoc,
    rerenderDiagramsForTheme,
  };
}
