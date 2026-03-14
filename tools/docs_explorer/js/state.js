const sidebarWidthStorageKey = "zide_docs_explorer.sidebar_width";
const sidebarCollapsedStorageKey = "zide_docs_explorer.sidebar_collapsed";
const themeStorageKey = "zide_docs_explorer.theme";

export const layoutDefaults = {
  collapseBreakpoint: 1100,
  minSidebarWidth: 220,
  maxSidebarWidth: 520,
  defaultSidebarWidth: 300,
};

/** @returns {import("./types.js").AppState} */
export function createAppState() {
  return {
    currentDoc: null,
    theme: preferredTheme(),
    document: {
      title: "Docs Explorer",
      subtitle: "",
      rawLink: "#",
      status: "idle",
    },
    viewer: {
      html: "",
    },
    search: {
      query: "",
    },
    tree: {
      filter: "",
      activePath: null,
    },
    sidebar: {
      width: preferredSidebarWidth(),
      collapsed: preferredSidebarCollapsed(),
    },
    optionsMenu: {
      open: false,
    },
  };
}

/** @returns {"dark" | "light"} */
export function preferredTheme() {
  const stored = localStorage.getItem(themeStorageKey);
  if (stored === "light" || stored === "dark") return stored;
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

/** @returns {number} */
export function preferredSidebarWidth() {
  const stored = Number(localStorage.getItem(sidebarWidthStorageKey));
  if (!Number.isNaN(stored) && stored >= layoutDefaults.minSidebarWidth && stored <= layoutDefaults.maxSidebarWidth) {
    return stored;
  }
  return layoutDefaults.defaultSidebarWidth;
}

/** @returns {boolean} */
export function preferredSidebarCollapsed() {
  return localStorage.getItem(sidebarCollapsedStorageKey) === "true";
}

/** @param {number} width */
export function clampSidebarWidth(width) {
  return Math.max(layoutDefaults.minSidebarWidth, Math.min(layoutDefaults.maxSidebarWidth, width));
}

/** @param {number} width */
export function persistSidebarWidth(width) {
  localStorage.setItem(sidebarWidthStorageKey, String(width));
}

/** @param {boolean} collapsed */
export function persistSidebarCollapsed(collapsed) {
  localStorage.setItem(sidebarCollapsedStorageKey, collapsed ? "true" : "false");
}

/** @param {"dark" | "light"} theme */
export function persistTheme(theme) {
  localStorage.setItem(themeStorageKey, theme);
}

/** @param {import("./types.js").AppState} state
 *  @param {string | null} path
 */
export function setCurrentDoc(state, path) {
  state.currentDoc = path;
}

/** @param {import("./types.js").AppState} state
 *  @param {string} query
 */
export function setSearchQuery(state, query) {
  state.search.query = query;
}

/** @param {import("./types.js").AppState} state
 *  @param {string} filter
 */
export function setTreeFilter(state, filter) {
  state.tree.filter = filter;
}

/** @param {import("./types.js").AppState} state
 *  @param {string | null} activePath
 */
export function setTreeActivePath(state, activePath) {
  state.tree.activePath = activePath;
}

/** @param {import("./types.js").AppState} state
 *  @param {boolean} open
 */
export function setOptionsMenuOpen(state, open) {
  state.optionsMenu.open = open;
}

/** @param {import("./types.js").AppState} state
 *  @param {"dark" | "light"} theme
 */
export function setTheme(state, theme) {
  state.theme = theme;
}

/** @param {import("./types.js").AppState} state
 *  @param {{ title: string, subtitle: string, rawLink: string, status: "idle" | "loading" | "ready" | "error" }} nextDocument
 */
export function setDocumentState(state, nextDocument) {
  state.document = nextDocument;
}

/** @param {import("./types.js").AppState} state
 *  @param {string} html
 */
export function setViewerHtml(state, html) {
  state.viewer.html = html;
}
