import { setDocumentState } from "../state.js";
import { docFetchPath, escapeHtml } from "../shared/utils.js";
import type { AppShell, AppState } from "../shared/types.js";

function setDocumentStatus(
  state: AppState,
  repoBasePath: string,
  repoAbsolutePath: string | undefined,
  path: string,
  status: AppState["document"]["status"],
): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: docFetchPath(repoBasePath, repoAbsolutePath, path),
    status,
  });
}

export function setDocumentLoading(
  state: AppState,
  repoBasePath: string,
  repoAbsolutePath: string | undefined,
  path: string,
): void {
  setDocumentStatus(state, repoBasePath, repoAbsolutePath, path, "loading");
}

export function setDocumentReady(
  state: AppState,
  repoBasePath: string,
  repoAbsolutePath: string | undefined,
  path: string,
): void {
  setDocumentStatus(state, repoBasePath, repoAbsolutePath, path, "ready");
}

export function setDocumentError(
  state: AppState,
  repoBasePath: string,
  repoAbsolutePath: string | undefined,
  path: string,
): void {
  setDocumentStatus(state, repoBasePath, repoAbsolutePath, path, "error");
}

export function renderDocumentChrome(
  state: AppState,
  shell: AppShell,
  appIconPath: string,
  appWordmarkText: string,
): void {
  shell.titleEl.innerHTML =
    `<span class="app-wordmark"><img class="app-wordmark-mark" src="${escapeHtml(appIconPath)}" alt="" aria-hidden="true" />${escapeHtml(appWordmarkText)} Docs Explorer</span>`;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
}
