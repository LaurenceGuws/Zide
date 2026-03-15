import { escapeHtml } from "./utils.js";
import { treeCaretIcon, treeFolderIcon } from "./tree_icons.js";

type TreeFile = {
  path: string;
  label: string;
  detail: string;
};

type TreeNode = {
  name: string;
  path: string;
  dirs: Map<string, TreeNode>;
  files: TreeFile[];
};

function buildTreeModel(paths: string[]): TreeNode {
  const root: TreeNode = { name: "", path: "", dirs: new Map(), files: [] };

  for (const path of paths) {
    const parts = path.split("/");
    let node = root;
    let current = "";
    for (let i = 0; i < parts.length; i += 1) {
      const part = parts[i];
      current = current ? `${current}/${part}` : part;
      const isFile = i === parts.length - 1;
      if (isFile) {
        node.files.push({
          path,
          label: part,
          detail: parts.slice(0, -1).join("/"),
        });
      } else {
        if (!node.dirs.has(part)) {
          node.dirs.set(part, {
            name: part,
            path: current,
            dirs: new Map(),
            files: [],
          });
        }
        node = node.dirs.get(part)!;
      }
    }
  }

  return root;
}

function renderTreeNode(node: TreeNode, activePath: string): string {
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
      const shouldOpen = isActiveBranch || expandedPathsGlobal.has(dir.path);
      return `
      <li class="tree-item">
        <details class="tree-folder ${isActiveBranch ? "active-branch" : ""}" data-folder-path="${escapeHtml(dir.path)}" ${shouldOpen ? "open" : ""}>
          <summary>
            <span class="folder-caret" aria-hidden="true">${treeCaretIcon()}</span>
            <span class="folder-icon" aria-hidden="true">${treeFolderIcon(shouldOpen)}</span>
            <span class="folder-label">${escapeHtml(dir.name)}</span>
          </summary>
          <div class="folder-children">
            ${renderTreeNode(dir, activePath)}
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

let expandedPathsGlobal = new Set<string>();

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
  expandedPathsGlobal = new Set(expandedPaths);
  const model = buildTreeModel(filtered);
  treeEl.innerHTML = `<ul class="tree-root">${renderTreeNode(model, activePath || "")}</ul>`;
  treeEl
    .querySelectorAll<HTMLDetailsElement>(".tree-folder")
    .forEach((folderEl) => {
      const path = folderEl.dataset.folderPath;
      if (!path) return;
      folderEl.addEventListener("toggle", () => {
        const nextExpanded = new Set(expandedPathsGlobal);
        if (folderEl.open) nextExpanded.add(path);
        else nextExpanded.delete(path);
        expandedPathsGlobal = nextExpanded;
        const iconEl = folderEl.querySelector<HTMLElement>(".folder-icon");
        if (iconEl) {
          iconEl.innerHTML = treeFolderIcon(folderEl.open);
        }
        onExpandedPathsChange?.(Array.from(nextExpanded).sort());
      });
    });
  syncActiveLink(activePath);
}
