import { escapeHtml } from "./utils.js";

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
  const dirEntries = Array.from(node.dirs.values()).sort((a, b) => a.name.localeCompare(b.name));
  const fileEntries = node.files.slice().sort((a, b) => a.path.localeCompare(b.path));

  const dirsHtml = dirEntries.map((dir) => {
    const shouldOpen = activePath.startsWith(`${dir.path}/`) || activePath === dir.path;
    return `
      <li class="tree-item">
        <details class="tree-folder" ${shouldOpen ? "open" : ""}>
          <summary>
            <span class="folder-caret">▸</span>
            <span class="folder-label">${escapeHtml(dir.name)}</span>
          </summary>
          <div class="folder-children">
            ${renderTreeNode(dir, activePath)}
          </div>
        </details>
      </li>
    `;
  }).join("");

  const filesHtml = fileEntries.map((doc) => `
    <li class="tree-item">
      <a class="doc-link" href="#doc=${encodeURIComponent(doc.path)}" data-doc-link="${escapeHtml(doc.path)}">
        <span class="doc-link-label">${escapeHtml(doc.label)}</span>
        <small class="doc-link-detail">${escapeHtml(doc.detail)}</small>
      </a>
    </li>
  `).join("");

  const dirList = dirsHtml ? `<ul class="folder-dir-list">${dirsHtml}</ul>` : "";
  const fileList = filesHtml ? `<ul class="folder-file-list">${filesHtml}</ul>` : "";
  return dirList + fileList;
}

export function syncActiveLink(activePath: string | null): void {
  const active = activePath || "";
  document.querySelectorAll<HTMLElement>("[data-doc-link]").forEach((el) => {
    el.classList.toggle("active", el.getAttribute("data-doc-link") === active);
  });
}

export function buildTree(treeEl: HTMLElement, docs: string[], activePath: string | null, filter = ""): void {
  const q = filter.trim().toLowerCase();
  const filtered = docs.filter((path) => q === "" || path.toLowerCase().includes(q));
  const model = buildTreeModel(filtered);
  treeEl.innerHTML = `<ul class="tree-root">${renderTreeNode(model, activePath || "")}</ul>`;
  syncActiveLink(activePath);
}
