import { rerenderVisibleMermaid } from "./mermaid.js";
import { renderCurrentDocCycle } from "./doc_render_cycle.js";
import { applySearchQuery, installDocRouting } from "./doc_routing.js";
import {
  renderTreeFromState,
  updateTreeExpandedPaths,
} from "../tree/tree_state.js";
import type { AppShell, AppState } from "../shared/types.js";
import type {
  HighlightJsApi,
  MarkedApi,
  MermaidApi,
} from "../shared/vendor_types.js";

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
    await renderCurrentDocCycle({
      state,
      shell,
      appIconPath,
      repoBasePath,
      repoAbsolutePath,
      docs,
      defaultDocPath,
      viewerEl,
      marked,
      mermaid,
      hljs,
      rootEl,
      renderTree,
    });
  }

  function renderTree(): void {
    renderTreeFromState(state, treeEl, docs, (expandedPaths) => {
      updateTreeExpandedPaths(state, expandedPaths);
    });
  }

  function install(): void {
    installDocRouting({
      searchEl,
      renderCurrentDoc,
      onSearchQuery(query: string) {
        applySearchQuery({ state, query, renderTree });
      },
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
