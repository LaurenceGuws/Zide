import { setDocumentState } from "./state.js";
import { repoRelative } from "./utils.js";
export function setDocumentLoading(state, repoBasePath, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        status: "loading",
    });
}
export function setDocumentReady(state, repoBasePath, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        status: "ready",
    });
}
export function setDocumentError(state, repoBasePath, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        status: "error",
    });
}
export function renderDocumentChrome(state, shell) {
    shell.titleEl.textContent = state.document.title;
    shell.subtitleEl.textContent = state.document.subtitle;
    shell.rawLinkEl.href = state.document.rawLink;
}
