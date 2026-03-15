import { setTreeActivePath, setTreeExpandedPaths, setTreeFilter } from "./state.js";
import { buildTree } from "./tree.js";
export function updateTreeFilter(state, filter) {
    setTreeFilter(state, filter);
}
export function updateTreeActivePath(state, activePath) {
    setTreeActivePath(state, activePath);
}
export function updateTreeExpandedPaths(state, expandedPaths) {
    setTreeExpandedPaths(state, expandedPaths);
}
export function renderTreeFromState(state, treeEl, docs, onExpandedPathsChange) {
    buildTree(treeEl, docs, state.tree.activePath, state.tree.filter, state.tree.expandedPaths, onExpandedPathsChange);
}
