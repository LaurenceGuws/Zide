import { setTreeActivePath, setTreeExpandedPaths, setTreeFilter } from "./state.js";
import { buildTree } from "./tree.js";
import type { AppState } from "./types.js";

export function updateTreeFilter(state: AppState, filter: string): void {
  setTreeFilter(state, filter);
}

export function updateTreeActivePath(state: AppState, activePath: string | null): void {
  setTreeActivePath(state, activePath);
}

export function updateTreeExpandedPaths(state: AppState, expandedPaths: string[]): void {
  setTreeExpandedPaths(state, expandedPaths);
}

export function renderTreeFromState(
  state: AppState,
  treeEl: HTMLElement,
  docs: string[],
  onExpandedPathsChange: (expandedPaths: string[]) => void,
): void {
  buildTree(treeEl, docs, state.tree.activePath, state.tree.filter, state.tree.expandedPaths, onExpandedPathsChange);
}
