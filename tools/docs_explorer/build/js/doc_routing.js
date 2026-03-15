import { setSearchQuery } from "./state.js";
import { updateTreeFilter } from "./tree_state.js";
export function applySearchQuery(args) {
    const { state, query, renderTree } = args;
    setSearchQuery(state, query);
    updateTreeFilter(state, query);
    renderTree();
}
export function installDocRouting(args) {
    const { searchEl, renderCurrentDoc, onSearchQuery } = args;
    searchEl.addEventListener("input", () => {
        onSearchQuery(searchEl.value);
    });
    window.addEventListener("hashchange", () => {
        void renderCurrentDoc();
    });
}
