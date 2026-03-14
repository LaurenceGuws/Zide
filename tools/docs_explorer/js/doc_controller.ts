import { rerenderVisibleMermaid } from "./mermaid.js";
import { currentDocFromHash } from "./utils.js";
import { setCurrentDoc, setSearchQuery } from "./state.js";
import { renderTreeFromState, updateTreeActivePath, updateTreeFilter } from "./tree_state.js";
import { renderDocumentChrome, setDocumentError, setDocumentLoading, setDocumentReady } from "./view_state.js";
import { loadDoc } from "./viewer.js";
import type { AppShell, AppState } from "./types.js";
import type { MarkedApi, MermaidApi } from "./vendor_types.js";

export function createDocController(args: {
  state: AppState;
  shell: AppShell;
  repoBasePath: string;
  docs: string[];
  defaultDocPath: string;
  treeEl: HTMLElement;
  viewerEl: HTMLElement;
  searchEl: HTMLInputElement;
  marked: MarkedApi;
  mermaid: MermaidApi;
  rootEl: HTMLElement;
}) {
  const {
    state,
    shell,
    repoBasePath,
    docs,
    defaultDocPath,
    treeEl,
    viewerEl,
    searchEl,
    marked,
    mermaid,
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
      path: state.currentDoc,
      marked,
      mermaid,
      rootEl,
      viewerEl,
      docs,
      defaultDocPath,
      onLoading(nextState: AppState, path: string) {
        setDocumentLoading(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell);
      },
      onReady(nextState: AppState, path: string) {
        setDocumentReady(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell);
      },
      onError(nextState: AppState, path: string) {
        setDocumentError(nextState, repoBasePath, path);
        renderDocumentChrome(nextState, shell);
      },
    });
  }

  function renderTree(): void {
    renderTreeFromState(state, treeEl, docs);
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
