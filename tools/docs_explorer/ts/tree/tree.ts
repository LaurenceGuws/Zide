import { buildTreeModel } from "./tree_model.js";
import { treeFolderIcon } from "./tree_icons.js";
import { renderTreeMarkup } from "./tree_markup.js";

export function syncActiveLink(activePath: string | null): void {
  const active = activePath || "";
  document.querySelectorAll<HTMLElement>("[data-doc-link]").forEach((el) => {
    el.classList.toggle("active", el.getAttribute("data-doc-link") === active);
  });
}

export function buildTree(
  treeEl: HTMLElement,
  docs: string[],
  activePath: string | null,
  filter = "",
  expandedPaths: string[] = [],
  onExpandedPathsChange?: (expandedPaths: string[]) => void,
): void {
  const q = filter.trim().toLowerCase();
  const filtered = docs.filter(
    (path) => q === "" || path.toLowerCase().includes(q),
  );
  let currentExpandedPaths = new Set(expandedPaths);
  const model = buildTreeModel(filtered);
  treeEl.innerHTML = renderTreeMarkup(
    model,
    activePath || "",
    currentExpandedPaths,
  );
  treeEl
    .querySelectorAll<HTMLDetailsElement>(".tree-folder")
    .forEach((folderEl) => {
      const path = folderEl.dataset.folderPath;
      if (!path) return;
      folderEl.addEventListener("toggle", () => {
        const nextExpanded = new Set(currentExpandedPaths);
        if (folderEl.open) nextExpanded.add(path);
        else nextExpanded.delete(path);
        currentExpandedPaths = nextExpanded;
        const iconEl = folderEl.querySelector<HTMLElement>(".folder-icon");
        if (iconEl) {
          iconEl.innerHTML = treeFolderIcon(folderEl.open);
        }
        onExpandedPathsChange?.(Array.from(nextExpanded).sort());
      });
    });
  syncActiveLink(activePath);
}
