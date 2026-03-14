import { setTreeActivePath, setTreeFilter } from "./state.js";
import { buildTree } from "./tree.js";

/** @param {import("./types.js").AppState} state
 *  @param {string} filter
 */
export function updateTreeFilter(state, filter) {
  setTreeFilter(state, filter);
}

/** @param {import("./types.js").AppState} state
 *  @param {string | null} activePath
 */
export function updateTreeActivePath(state, activePath) {
  setTreeActivePath(state, activePath);
}

/** @param {import("./types.js").AppState} state
 *  @param {HTMLElement} treeEl
 *  @param {string[]} docs
 */
export function renderTreeFromState(state, treeEl, docs) {
  buildTree(treeEl, docs, state.tree.activePath, state.tree.filter);
}
