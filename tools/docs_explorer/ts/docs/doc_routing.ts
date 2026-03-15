import { setSearchQuery } from "../state.js";
import { updateTreeFilter } from "../tree/tree_state.js";
import type { AppState } from "../shared/types.js";

export function applySearchQuery(args: {
  state: AppState;
  query: string;
  renderTree: () => void;
}): void {
  const { state, query, renderTree } = args;
  setSearchQuery(state, query);
  updateTreeFilter(state, query);
  renderTree();
}

export function installDocRouting(args: {
  searchEl: HTMLInputElement;
  renderCurrentDoc: () => Promise<void>;
  onSearchQuery: (query: string) => void;
}): void {
  const { searchEl, renderCurrentDoc, onSearchQuery } = args;

  searchEl.addEventListener("input", () => {
    onSearchQuery(searchEl.value);
  });

  window.addEventListener("hashchange", () => {
    void renderCurrentDoc();
  });
}
