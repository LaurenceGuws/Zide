import { setDocumentState } from "./state.js";
import { escapeHtml, repoRelative } from "./utils.js";
import type { AppShell, AppState } from "./types.js";

export function setDocumentLoading(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "loading",
  });
}

export function setDocumentReady(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "ready",
  });
}

export function setDocumentError(
  state: AppState,
  repoBasePath: string,
  path: string,
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    status: "error",
  });
}

export function renderDocumentChrome(
  state: AppState,
  shell: AppShell,
  appIconPath: string,
): void {
  shell.titleEl.innerHTML =
    `<span class="app-wordmark"><img class="app-wordmark-mark" src="${escapeHtml(appIconPath)}" alt="" aria-hidden="true" />ide Docs Explorer</span>`;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
}
