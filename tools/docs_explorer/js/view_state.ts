import { setDocumentState } from "./state.js";
import { repoRelative } from "./utils.js";
import type { AppShell, AppState } from "./types.js";

export function setDocumentLoading(state: AppState, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "loading",
  });
}

export function setDocumentReady(state: AppState, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "ready",
  });
}

export function setDocumentError(state: AppState, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "error",
  });
}

export function renderDocumentChrome(state: AppState, shell: AppShell): void {
  shell.titleEl.textContent = state.document.title;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
}
