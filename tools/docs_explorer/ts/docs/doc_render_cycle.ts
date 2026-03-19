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

function syncCurrentDocSelection(
  state: AppState,
  docs: string[],
  defaultDocPath: string,
  renderTree: () => void,
): void {
  const currentPath = currentDocFromHash(docs, defaultDocPath);
  setCurrentDoc(state, currentPath);
  updateTreeActivePath(state, currentPath);
  renderTree();
}

function renderDocumentLifecycleChrome(args: {
  state: AppState;
  shell: AppShell;
  appIconPath: string;
  appWordmarkText: string;
  repoBasePath: string;
  repoAbsolutePath?: string;
  path: string;
  status: AppState["document"]["status"];
}): void {
  const { state, shell, appIconPath, appWordmarkText, repoBasePath, repoAbsolutePath, path, status } = args;

  if (status === "loading") {
    setDocumentLoading(state, repoBasePath, repoAbsolutePath, path);
  } else if (status === "ready") {
    setDocumentReady(state, repoBasePath, repoAbsolutePath, path);
  } else {
    setDocumentError(state, repoBasePath, repoAbsolutePath, path);
  }

  renderDocumentChrome(state, shell, appIconPath, appWordmarkText);
}

export async function renderCurrentDocCycle(args: {
  state: AppState;
  shell: AppShell;
  appIconPath: string;
  appWordmarkText: string;
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
    appWordmarkText,
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

  syncCurrentDocSelection(state, docs, defaultDocPath, renderTree);

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
      renderDocumentLifecycleChrome({
        state: nextState,
        shell,
        appIconPath,
        appWordmarkText,
        repoBasePath,
        repoAbsolutePath,
        path,
        status: "loading",
      });
    },
    onReady(nextState: AppState, path: string) {
      renderDocumentLifecycleChrome({
        state: nextState,
        shell,
        appIconPath,
        appWordmarkText,
        repoBasePath,
        repoAbsolutePath,
        path,
        status: "ready",
      });
      renderHighlightedCode(hljs, viewerEl);
    },
    onError(nextState: AppState, path: string) {
      renderDocumentLifecycleChrome({
        state: nextState,
        shell,
        appIconPath,
        appWordmarkText,
        repoBasePath,
        repoAbsolutePath,
        path,
        status: "error",
      });
    },
  });
}
