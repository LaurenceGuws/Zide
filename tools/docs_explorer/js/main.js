import { marked } from "https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js";
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

import { configureMarked } from "./markdown.js";
import { initMermaidForTheme, rerenderVisibleMermaid } from "./mermaid.js";
import { buildTree } from "./tree.js";
import { currentDocFromHash } from "./utils.js";
import { applyTheme, currentTheme, preferredTheme, updateThemeToggle } from "./theme.js";
import { loadDoc } from "./viewer.js";

const sidebarWidthStorageKey = "zide_docs_explorer.sidebar_width";
const sidebarCollapsedStorageKey = "zide_docs_explorer.sidebar_collapsed";
const collapseBreakpoint = 1100;
const minSidebarWidth = 220;
const maxSidebarWidth = 520;

async function fetchJson(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${path}`);
  return res.json();
}

function preferredSidebarWidth() {
  const stored = Number(localStorage.getItem(sidebarWidthStorageKey));
  if (!Number.isNaN(stored) && stored >= minSidebarWidth && stored <= maxSidebarWidth) {
    return stored;
  }
  return 300;
}

function setSidebarWidth(appEl, width) {
  const clamped = Math.max(minSidebarWidth, Math.min(maxSidebarWidth, width));
  appEl.style.setProperty("--sidebar-width", `${clamped}px`);
  localStorage.setItem(sidebarWidthStorageKey, String(clamped));
}

function setSidebarCollapsed(appEl, collapsed) {
  appEl.dataset.sidebarCollapsed = collapsed ? "true" : "false";
  localStorage.setItem(sidebarCollapsedStorageKey, collapsed ? "true" : "false");
}

function applyResponsiveSidebarState(appEl) {
  if (window.innerWidth <= collapseBreakpoint) {
    setSidebarCollapsed(appEl, true);
    return;
  }
  const stored = localStorage.getItem(sidebarCollapsedStorageKey);
  setSidebarCollapsed(appEl, stored === "true");
}

async function main() {
  const [project, docs] = await Promise.all([
    fetchJson("./config/project.json"),
    fetchJson("./config/docs-index.json"),
  ]);

  const treeEl = document.getElementById("tree");
  const viewerEl = document.getElementById("viewer");
  const titleEl = document.getElementById("doc-title");
  const subtitleEl = document.getElementById("doc-subtitle");
  const rawLinkEl = document.getElementById("raw-link");
  const searchEl = document.getElementById("search");
  const themeToggleEl = document.getElementById("theme-toggle");
  const sidebarToggleEl = document.getElementById("sidebar-toggle");
  const sidebarResizerEl = document.getElementById("sidebar-resizer");
  const rootEl = document.documentElement;
  const appEl = document.querySelector(".app");

  document.title = project.title;
  document.getElementById("app-title").textContent = project.title;
  document.getElementById("brand-mark").src = project.icon;
  document.getElementById("brand-mark").alt = `${project.title} logo`;
  document.getElementById("favicon").href = project.icon;

  rootEl.dataset.theme = preferredTheme();
  setSidebarWidth(appEl, preferredSidebarWidth());
  applyResponsiveSidebarState(appEl);
  configureMarked(marked);
  initMermaidForTheme(mermaid, rootEl, currentTheme(rootEl));
  updateThemeToggle(themeToggleEl, currentTheme(rootEl));

  const defaultDocPath = project.defaultDoc;

  const renderCurrentDoc = () => loadDoc({
    path: currentDocFromHash(docs, defaultDocPath),
    marked,
    mermaid,
    rootEl,
    viewerEl,
    titleEl,
    subtitleEl,
    rawLinkEl,
    docs,
    defaultDocPath,
  });

  searchEl.addEventListener("input", () => buildTree(treeEl, docs, defaultDocPath, searchEl.value));
  window.addEventListener("hashchange", renderCurrentDoc);
  window.addEventListener("resize", () => applyResponsiveSidebarState(appEl));
  themeToggleEl.addEventListener("click", async () => {
    await applyTheme(
      rootEl,
      themeToggleEl,
      currentTheme(rootEl) === "dark" ? "light" : "dark",
      () => rerenderVisibleMermaid(mermaid, rootEl, viewerEl),
    );
  });
  sidebarToggleEl.addEventListener("click", () => {
    const collapsed = appEl.dataset.sidebarCollapsed !== "true";
    setSidebarCollapsed(appEl, collapsed);
  });

  let resizeState = null;
  sidebarResizerEl.addEventListener("pointerdown", (event) => {
    if (window.innerWidth <= collapseBreakpoint) return;
    resizeState = {
      startX: event.clientX,
      startWidth: preferredSidebarWidth(),
    };
    appEl.dataset.resizing = "true";
    sidebarResizerEl.setPointerCapture(event.pointerId);
  });
  sidebarResizerEl.addEventListener("pointermove", (event) => {
    if (!resizeState) return;
    const delta = event.clientX - resizeState.startX;
    setSidebarWidth(appEl, resizeState.startWidth + delta);
  });
  const endResize = () => {
    resizeState = null;
    appEl.dataset.resizing = "false";
  };
  sidebarResizerEl.addEventListener("pointerup", endResize);
  sidebarResizerEl.addEventListener("pointercancel", endResize);

  buildTree(treeEl, docs, defaultDocPath);
  await renderCurrentDoc();
}

main().catch((err) => {
  const viewerEl = document.getElementById("viewer");
  viewerEl.innerHTML = `
    <div class="callout">
      Failed to initialize docs explorer.
    </div>
    <pre><code>${String(err).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")}</code></pre>
  `;
});
