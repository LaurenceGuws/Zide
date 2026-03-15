import { setDocumentState } from "../state.js";
import { escapeHtml, repoRelative } from "../shared/utils.js";
function setDocumentStatus(state, repoBasePath, path, status) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        status,
    });
}
export function setDocumentLoading(state, repoBasePath, path) {
    setDocumentStatus(state, repoBasePath, path, "loading");
}
export function setDocumentReady(state, repoBasePath, path) {
    setDocumentStatus(state, repoBasePath, path, "ready");
}
export function setDocumentError(state, repoBasePath, path) {
    setDocumentStatus(state, repoBasePath, path, "error");
}
export function renderDocumentChrome(state, shell, appIconPath) {
    shell.titleEl.innerHTML =
        `<span class="app-wordmark"><img class="app-wordmark-mark" src="${escapeHtml(appIconPath)}" alt="" aria-hidden="true" />ide Docs Explorer</span>`;
    shell.subtitleEl.textContent = state.document.subtitle;
    shell.rawLinkEl.href = state.document.rawLink;
}
