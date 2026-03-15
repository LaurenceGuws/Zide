import { rerenderVisibleMermaid } from "./mermaid.js";
import { renderCurrentDocCycle } from "./doc_render_cycle.js";
import { applySearchQuery, installDocRouting } from "./doc_routing.js";
import { renderTreeFromState, updateTreeExpandedPaths, } from "../tree/tree_state.js";
export function createDocController(args) {
    const { state, shell, appIconPath, repoBasePath, repoAbsolutePath, docs, defaultDocPath, treeEl, viewerEl, searchEl, marked, mermaid, hljs, rootEl, } = args;
    async function renderCurrentDoc() {
        await renderCurrentDocCycle({
            state,
            shell,
            appIconPath,
            repoBasePath,
            repoAbsolutePath,
            docs,
            defaultDocPath,
            viewerEl,
            marked,
            mermaid,
            hljs,
            rootEl,
            renderTree,
        });
    }
    function renderTree() {
        renderTreeFromState(state, treeEl, docs, (expandedPaths) => {
            updateTreeExpandedPaths(state, expandedPaths);
        });
    }
    function install() {
        installDocRouting({
            searchEl,
            renderCurrentDoc,
            onSearchQuery(query) {
                applySearchQuery({ state, query, renderTree });
            },
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
