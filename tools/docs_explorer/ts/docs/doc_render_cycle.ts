import { renderHighlightedCode } from "./highlight.js";
import { currentDocFromHash } from "../shared/utils.js";
import { setCurrentDoc } from "../state.js";
import {
  setDocumentError,
  setDocumentLoading,
  setDocumentReady,
  renderDocumentChrome,
} from "./view_state.js";
import { loadDoc } from "./viewer.js";
import { updateTreeActivePath } from "../tree/tree_state.js";
import type { AppShell, AppState } from "../shared/types.js";
import type {
  HighlightJsApi,
  MarkedApi,
  MermaidApi,
} from "../shared/vendor_types.js";

export async function renderCurrentDocCycle(args: {
  state: AppState;
  shell: AppShell;
  appIconPath: string;
  repoBasePath: string;
  repoAbsolutePath?: string;
  docs: string[];
  defaultDocPath: string;
  viewerEl: HTMLElement;
  marked: MarkedApi;
  mermaid: MermaidApi;
  hljs?: HighlightJsApi;
  rootEl: HTMLElement;
  renderTree: () => void;
}): Promise<void> {
  const {
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
  } = args;

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
