import { escapeHtml } from "../shared/utils.js";
import { treeCaretIcon, treeFolderIcon } from "./tree_icons.js";
import type { TreeNode } from "./tree_model.js";

function renderTreeNode(
  node: TreeNode,
  activePath: string,
  expandedPaths: ReadonlySet<string>,
): string {
  const dirEntries = Array.from(node.dirs.values()).sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const fileEntries = node.files
    .slice()
    .sort((a, b) => a.path.localeCompare(b.path));

  const dirsHtml = dirEntries
    .map((dir) => {
      const isActiveBranch =
        activePath.startsWith(`${dir.path}/`) || activePath === dir.path;
      const shouldOpen = isActiveBranch || expandedPaths.has(dir.path);
      return `
      <li class="tree-item">
        <details class="tree-folder ${isActiveBranch ? "active-branch" : ""}" data-folder-path="${escapeHtml(dir.path)}" ${shouldOpen ? "open" : ""}>
          <summary>
            <span class="folder-caret" aria-hidden="true">${treeCaretIcon()}</span>
            <span class="folder-icon" aria-hidden="true">${treeFolderIcon(shouldOpen)}</span>
            <span class="folder-label">${escapeHtml(dir.name)}</span>
          </summary>
          <div class="folder-children">
            ${renderTreeNode(dir, activePath, expandedPaths)}
          </div>
        </details>
      </li>
    `;
    })
    .join("");

  const filesHtml = fileEntries
    .map(
      (doc) => `
    <li class="tree-item">
      <a class="doc-link" href="#doc=${encodeURIComponent(doc.path)}" data-doc-link="${escapeHtml(doc.path)}">
        <span class="doc-link-label">${escapeHtml(doc.label)}</span>
        <small class="doc-link-detail">${escapeHtml(doc.detail)}</small>
      </a>
    </li>
  `,
    )
    .join("");

  const dirList = dirsHtml
    ? `<ul class="folder-dir-list">${dirsHtml}</ul>`
    : "";
  const fileList = filesHtml
    ? `<ul class="folder-file-list">${filesHtml}</ul>`
    : "";
  return dirList + fileList;
}

export function renderTreeMarkup(
  model: TreeNode,
  activePath: string,
  expandedPaths: ReadonlySet<string>,
): string {
  return `<ul class="tree-root">${renderTreeNode(model, activePath, expandedPaths)}</ul>`;
}
