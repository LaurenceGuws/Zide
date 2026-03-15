import { escapeHtml } from "../shared/utils.js";
import { treeCaretIcon, treeFolderIcon } from "./tree_icons.js";
import type { TreeNode } from "./tree_model.js";

function getInnermostActiveFolderPath(activePath: string): string {
  const lastSlash = activePath.lastIndexOf("/");
  if (lastSlash <= 0) return "";
  return activePath.slice(0, lastSlash);
}

function renderTreeNode(
  node: TreeNode,
  activePath: string,
  expandedPaths: ReadonlySet<string>,
  innermostActiveFolderPath: string,
): string {
  const dirEntries = Array.from(node.dirs.values()).sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const fileEntries = node.files
    .slice()
    .sort((a, b) => a.path.localeCompare(b.path));

  const activeDirIndex = dirEntries.findIndex(
    (child) => activePath === child.path || activePath.startsWith(`${child.path}/`),
  );
  const activeFileIndex = fileEntries.findIndex((child) => activePath === child.path);
  const activeChildIndex =
    activeDirIndex >= 0
      ? activeDirIndex
      : activeFileIndex >= 0
        ? dirEntries.length + activeFileIndex
        : -1;

  const dirsHtml = dirEntries
    .map((dir, dirIndex) => {
      const isActiveBranch =
        activePath.startsWith(`${dir.path}/`) || activePath === dir.path;
      const shouldOpen = isActiveBranch || expandedPaths.has(dir.path);
      const isInnermostActiveFolder = dir.path === innermostActiveFolderPath;
      const rowIndex = dirIndex;
      const rowClasses = [
        "tree-item",
        shouldOpen ? "open-folder-row" : "",
        activeChildIndex >= 0 && rowIndex <= activeChildIndex
          ? "active-stem"
          : "",
        activeDirIndex === dirIndex ? "active-path-child" : "",
      ]
        .filter(Boolean)
        .join(" ");
      return `
      <li class="${rowClasses}">
        <details class="tree-folder ${isActiveBranch ? "active-branch" : ""} ${isInnermostActiveFolder ? "active-leaf-folder" : ""}" data-folder-path="${escapeHtml(dir.path)}" ${shouldOpen ? "open" : ""}>
          <summary>
            <span class="folder-caret" aria-hidden="true">${treeCaretIcon()}</span>
            <span class="folder-icon" aria-hidden="true">${treeFolderIcon(shouldOpen)}</span>
            <span class="folder-label">${escapeHtml(dir.name)}</span>
          </summary>
          <div class="folder-children">
            ${renderTreeNode(dir, activePath, expandedPaths, innermostActiveFolderPath)}
          </div>
        </details>
      </li>
    `;
    })
    .join("");

  const filesHtml = fileEntries
    .map((doc, fileIndex) => {
      const rowIndex = dirEntries.length + fileIndex;
      const rowClasses = [
        "tree-item",
        activeChildIndex >= 0 && rowIndex <= activeChildIndex
          ? "active-stem"
          : "",
        activePath === doc.path ? "active-path-child" : "",
      ]
        .filter(Boolean)
        .join(" ");
      return `
    <li class="${rowClasses}">
      <a class="doc-link" href="#doc=${encodeURIComponent(doc.path)}" data-doc-link="${escapeHtml(doc.path)}">
        <span class="doc-link-label">${escapeHtml(doc.label)}</span>
        <small class="doc-link-detail">${escapeHtml(doc.detail)}</small>
      </a>
    </li>
  `;
    })
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
  const innermostActiveFolderPath = getInnermostActiveFolderPath(activePath);
  return `<ul class="tree-root">${renderTreeNode(model, activePath, expandedPaths, innermostActiveFolderPath)}</ul>`;
}
