import { setDocumentState } from "./state.js";
import { repoRelative } from "./utils.js";

/** @param {import("./types.js").AppState} state
 *  @param {string} path
 */
export function setDocumentLoading(state, path) {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "loading",
  });
}

/** @param {import("./types.js").AppState} state
 *  @param {string} path
 */
export function setDocumentReady(state, path) {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "ready",
  });
}

/** @param {import("./types.js").AppState} state
 *  @param {string} path
 */
export function setDocumentError(state, path) {
  setDocumentState(state, {
    title: path,
    subtitle: "",
    rawLink: repoRelative(path),
    status: "error",
  });
}

/** @param {import("./types.js").AppState} state
 *  @param {import("./types.js").AppShell} shell
 */
export function renderDocumentChrome(state, shell) {
  shell.titleEl.textContent = state.document.title;
  shell.subtitleEl.textContent = state.document.subtitle;
  shell.rawLinkEl.href = state.document.rawLink;
}
