import { setDocumentState } from "./state.js";
import { repoRelative, repoSourceUrl } from "./utils.js";
import type { AppShell, AppState } from "./types.js";

export function setDocumentLoading(state: AppState, repoBasePath: string, sourceUrlBase: string | undefined, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    sourceLink: repoSourceUrl(sourceUrlBase, path),
    status: "loading",
  });
}

export function setDocumentReady(state: AppState, repoBasePath: string, sourceUrlBase: string | undefined, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    sourceLink: repoSourceUrl(sourceUrlBase, path),
    status: "ready",
  });
}

export function setDocumentError(state: AppState, repoBasePath: string, sourceUrlBase: string | undefined, path: string): void {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(repoBasePath, path),
    sourceLink: repoSourceUrl(sourceUrlBase, path),
    status: "error",
  });
}

export function renderDocumentChrome(state: AppState, shell: AppShell): void {
  shell.titleEl.textContent = `Zide Docs Explorer - ${state.document.title}`;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
  shell.sourceLinkEl.href = state.document.sourceLink;
}
