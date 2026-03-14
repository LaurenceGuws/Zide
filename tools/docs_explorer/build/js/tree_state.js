import { setTreeActivePath, setTreeFilter } from "./state.js";
import { buildTree } from "./tree.js";
export function updateTreeFilter(state, filter) {
    setTreeFilter(state, filter);
}
export function updateTreeActivePath(state, activePath) {
    setTreeActivePath(state, activePath);
}
export function renderTreeFromState(state, treeEl, docs) {
    buildTree(treeEl, docs, state.tree.activePath, state.tree.filter);
}
