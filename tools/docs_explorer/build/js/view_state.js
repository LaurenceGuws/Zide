import { setDocumentState } from "./state.js";
import { repoRelative, repoSourceUrl } from "./utils.js";
export function setDocumentLoading(state, repoBasePath, sourceUrlBase, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        sourceLink: repoSourceUrl(sourceUrlBase, path),
        status: "loading",
    });
}
export function setDocumentReady(state, repoBasePath, sourceUrlBase, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        sourceLink: repoSourceUrl(sourceUrlBase, path),
        status: "ready",
    });
}
export function setDocumentError(state, repoBasePath, sourceUrlBase, path) {
    setDocumentState(state, {
        title: path,
        subtitle: "",
        rawLink: repoRelative(repoBasePath, path),
        sourceLink: repoSourceUrl(sourceUrlBase, path),
        status: "error",
    });
}
export function renderDocumentChrome(state, shell) {
    shell.titleEl.textContent = `Zide Docs Explorer - ${state.document.title}`;
    shell.subtitleEl.textContent = state.document.subtitle;
    shell.rawLinkEl.href = state.document.rawLink;
    shell.sourceLinkEl.href = state.document.sourceLink;
}
