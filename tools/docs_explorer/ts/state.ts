import type {
  AppState,
  DocumentStatus,
  ThemeName,
} from "./shared/types.js";

const sidebarWidthStorageKey = "zide_docs_explorer.sidebar_width";
const sidebarCollapsedStorageKey = "zide_docs_explorer.sidebar_collapsed";
const themeStorageKey = "zide_docs_explorer.theme";

export const layoutDefaults = {
  collapseBreakpoint: 1100,
  minSidebarWidth: 220,
  maxSidebarWidth: 520,
  defaultSidebarWidth: 300,
} as const;

export function createAppState(): AppState {
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
      expandedPaths: [],
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

export function preferredTheme(): ThemeName {
  const stored = localStorage.getItem(themeStorageKey);
  if (stored === "light" || stored === "dark") return stored;
  return window.matchMedia("(prefers-color-scheme: light)").matches
    ? "light"
    : "dark";
}

export function preferredSidebarWidth(): number {
  const stored = Number(localStorage.getItem(sidebarWidthStorageKey));
  if (
    !Number.isNaN(stored) &&
    stored >= layoutDefaults.minSidebarWidth &&
    stored <= layoutDefaults.maxSidebarWidth
  ) {
    return stored;
  }
  return layoutDefaults.defaultSidebarWidth;
}

export function preferredSidebarCollapsed(): boolean {
  return localStorage.getItem(sidebarCollapsedStorageKey) === "true";
}

export function clampSidebarWidth(width: number): number {
  return Math.max(
    layoutDefaults.minSidebarWidth,
    Math.min(layoutDefaults.maxSidebarWidth, width),
  );
}

export function persistSidebarWidth(width: number): void {
  localStorage.setItem(sidebarWidthStorageKey, String(width));
}

export function persistSidebarCollapsed(collapsed: boolean): void {
  localStorage.setItem(
    sidebarCollapsedStorageKey,
    collapsed ? "true" : "false",
  );
}

export function persistTheme(theme: ThemeName): void {
  localStorage.setItem(themeStorageKey, theme);
}

export function setCurrentDoc(state: AppState, path: string | null): void {
  state.currentDoc = path;
}

export function setSearchQuery(state: AppState, query: string): void {
  state.search.query = query;
}

export function setTreeFilter(state: AppState, filter: string): void {
  state.tree.filter = filter;
}

export function setTreeActivePath(
  state: AppState,
  activePath: string | null,
): void {
  state.tree.activePath = activePath;
}

export function setTreeExpandedPaths(
  state: AppState,
  expandedPaths: string[],
): void {
  state.tree.expandedPaths = expandedPaths;
}

export function setOptionsMenuOpen(state: AppState, open: boolean): void {
  state.optionsMenu.open = open;
}

export function setTheme(state: AppState, theme: ThemeName): void {
  state.theme = theme;
}

export function setDocumentState(
  state: AppState,
  nextDocument: {
    title: string;
    subtitle: string;
    rawLink: string;
    status: DocumentStatus;
  },
): void {
  state.document = nextDocument;
}

export function setViewerHtml(state: AppState, html: string): void {
  state.viewer.html = html;
}
