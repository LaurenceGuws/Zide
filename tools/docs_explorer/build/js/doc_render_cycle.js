import { renderHighlightedCode } from "./highlight.js";
import { currentDocFromHash } from "./utils.js";
import { setCurrentDoc } from "./state.js";
import { setDocumentError, setDocumentLoading, setDocumentReady, renderDocumentChrome, } from "./view_state.js";
import { loadDoc } from "./viewer.js";
import { updateTreeActivePath } from "./tree_state.js";
export async function renderCurrentDocCycle(args) {
    const { state, shell, appIconPath, repoBasePath, repoAbsolutePath, docs, defaultDocPath, viewerEl, marked, mermaid, hljs, rootEl, renderTree, } = args;
    const currentPath = currentDocFromHash(docs, defaultDocPath);
    setCurrentDoc(state, currentPath);
    updateTreeActivePath(state, currentPath);
    renderTree();
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
        onLoading(nextState, path) {
            setDocumentLoading(nextState, repoBasePath, path);
            renderDocumentChrome(nextState, shell, appIconPath);
        },
        onReady(nextState, path) {
            setDocumentReady(nextState, repoBasePath, path);
            renderDocumentChrome(nextState, shell, appIconPath);
            renderHighlightedCode(hljs, viewerEl);
        },
        onError(nextState, path) {
            setDocumentError(nextState, repoBasePath, path);
            renderDocumentChrome(nextState, shell, appIconPath);
        },
    });
}
