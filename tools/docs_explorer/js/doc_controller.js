import { rerenderVisibleMermaid } from "./mermaid.js";
import { currentDocFromHash } from "./utils.js";
import { setCurrentDoc, setSearchQuery } from "./state.js";
import { renderTreeFromState, updateTreeActivePath, updateTreeFilter } from "./tree_state.js";
import { renderDocumentChrome, setDocumentError, setDocumentLoading, setDocumentReady } from "./view_state.js";
import { loadDoc } from "./viewer.js";

export function createDocController({
  state,
  shell,
  docs,
  defaultDocPath,
  treeEl,
  viewerEl,
  searchEl,
  marked,
  mermaid,
  rootEl,
}) {
  async function renderCurrentDoc() {
    const currentPath = currentDocFromHash(docs, defaultDocPath);
    setCurrentDoc(state, currentPath);
    updateTreeActivePath(state, currentPath);
    renderTree();
    await loadDoc({
      state,
      path: state.currentDoc,
      marked,
      mermaid,
      rootEl,
      viewerEl,
      docs,
      defaultDocPath,
      onLoading(nextState, path) {
        setDocumentLoading(nextState, path);
        renderDocumentChrome(nextState, shell);
      },
      onReady(nextState, path) {
        setDocumentReady(nextState, path);
        renderDocumentChrome(nextState, shell);
      },
      onError(nextState, path) {
        setDocumentError(nextState, path);
        renderDocumentChrome(nextState, shell);
      },
    });
  }

  function renderTree() {
    renderTreeFromState(state, treeEl, docs);
  }

  function applySearchQuery(query) {
    setSearchQuery(state, query);
    updateTreeFilter(state, query);
    renderTree();
  }

  function install() {
    searchEl.addEventListener("input", () => {
      applySearchQuery(searchEl.value);
    });

    window.addEventListener("hashchange", renderCurrentDoc);
  }

  async function rerenderDiagramsForTheme() {
    await rerenderVisibleMermaid(mermaid, rootEl, viewerEl);
  }

  return {
    install,
    renderTree,
    renderCurrentDoc,
    rerenderDiagramsForTheme,
  };
}
