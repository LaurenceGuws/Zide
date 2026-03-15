import { setDocumentState } from "./state.js";
import { repoRelative } from "./utils.js";
import type { AppShell, AppState } from "./types.js";

export function setDocumentLoading(state: AppState, repoBasePath: string, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "loading",
  });
}

export function setDocumentReady(state: AppState, repoBasePath: string, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "ready",
  });
}

export function setDocumentError(state: AppState, repoBasePath: string, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "error",
  });
}

export function renderDocumentChrome(state: AppState, shell: AppShell): void {
  shell.titleEl.textContent = `Zide Docs Explorer - ${state.document.title}`;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
  shell.sourceLinkEl.href = state.document.rawLink;
}
