import { buildTreeModel } from "./tree_model.js";
import { treeFolderIcon } from "./tree_icons.js";
import { renderTreeMarkup } from "./tree_markup.js";
export function syncActiveLink(activePath) {
    const active = activePath || "";
    document.querySelectorAll("[data-doc-link]").forEach((el) => {
        el.classList.toggle("active", el.getAttribute("data-doc-link") === active);
    });
}
export function buildTree(treeEl, docs, activePath, filter = "", expandedPaths = [], onExpandedPathsChange) {
    const q = filter.trim().toLowerCase();
    const filtered = docs.filter((path) => q === "" || path.toLowerCase().includes(q));
    let currentExpandedPaths = new Set(expandedPaths);
    const model = buildTreeModel(filtered);
    treeEl.innerHTML = renderTreeMarkup(model, activePath || "", currentExpandedPaths);
    treeEl
        .querySelectorAll(".tree-folder")
        .forEach((folderEl) => {
        const path = folderEl.dataset.folderPath;
        if (!path)
            return;
        folderEl.addEventListener("toggle", () => {
            const nextExpanded = new Set(currentExpandedPaths);
            if (folderEl.open)
                nextExpanded.add(path);
            else
                nextExpanded.delete(path);
            currentExpandedPaths = nextExpanded;
            const iconEl = folderEl.querySelector(".folder-icon");
            if (iconEl) {
                iconEl.innerHTML = treeFolderIcon(folderEl.open);
            }
            onExpandedPathsChange?.(Array.from(nextExpanded).sort());
        });
    });
    syncActiveLink(activePath);
}
