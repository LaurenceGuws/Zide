import { rerenderVisibleMermaid } from "./mermaid.js";
import { renderHighlightedCode } from "./highlight.js";
import { currentDocFromHash } from "./utils.js";
import { setCurrentDoc, setSearchQuery } from "./state.js";
import { renderTreeFromState, updateTreeActivePath, updateTreeExpandedPaths, updateTreeFilter } from "./tree_state.js";
import { renderDocumentChrome, setDocumentError, setDocumentLoading, setDocumentReady } from "./view_state.js";
import { loadDoc } from "./viewer.js";
export function createDocController(args) {
    const { state, shell, repoBasePath, sourceUrlBase, repoAbsolutePath, docs, defaultDocPath, treeEl, viewerEl, searchEl, marked, mermaid, hljs, rootEl, } = args;
    async function renderCurrentDoc() {
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
                setDocumentLoading(nextState, repoBasePath, sourceUrlBase, path);
                renderDocumentChrome(nextState, shell);
            },
            onReady(nextState, path) {
                setDocumentReady(nextState, repoBasePath, sourceUrlBase, path);
                renderDocumentChrome(nextState, shell);
                renderHighlightedCode(hljs, viewerEl);
            },
            onError(nextState, path) {
                setDocumentError(nextState, repoBasePath, sourceUrlBase, path);
                renderDocumentChrome(nextState, shell);
            },
        });
    }
    function renderTree() {
        renderTreeFromState(state, treeEl, docs, (expandedPaths) => {
            updateTreeExpandedPaths(state, expandedPaths);
        });
    }
    function applySearchQuery(query) {
        setSearchQuery(state, query);
        updateTreeFilter(state, query);
        renderTree();
    }
    function install() {
        searchEl.addEventListener("input", () => {
            applySearchQuery(searchEl.value);
        });
        window.addEventListener("hashchange", () => {
            void renderCurrentDoc();
        });
    }
    async function rerenderDiagramsForTheme() {
        await rerenderVisibleMermaid(mermaid, rootEl, viewerEl);
    }
    return {
        install,
        renderTree,
        renderCurrentDoc,
        rerenderDiagramsForTheme,
    };
}
