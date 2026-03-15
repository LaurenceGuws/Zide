const sidebarWidthStorageKey = "zide_docs_explorer.sidebar_width";
const sidebarCollapsedStorageKey = "zide_docs_explorer.sidebar_collapsed";
const themeStorageKey = "zide_docs_explorer.theme";
export const layoutDefaults = {
    collapseBreakpoint: 1100,
    minSidebarWidth: 180,
    maxSidebarWidth: 760,
    defaultSidebarWidth: 320,
};
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
        textSearch: {
            query: "",
            open: false,
            status: "idle",
            selectedIndex: -1,
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
export function preferredTheme() {
    const stored = localStorage.getItem(themeStorageKey);
    if (stored === "light" || stored === "dark")
        return stored;
    return window.matchMedia("(prefers-color-scheme: light)").matches
        ? "light"
        : "dark";
}
export function preferredSidebarWidth() {
    const stored = Number(localStorage.getItem(sidebarWidthStorageKey));
    if (!Number.isNaN(stored) &&
        stored >= layoutDefaults.minSidebarWidth &&
        stored <= layoutDefaults.maxSidebarWidth) {
        return stored;
    }
    return layoutDefaults.defaultSidebarWidth;
}
export function preferredSidebarCollapsed() {
    return localStorage.getItem(sidebarCollapsedStorageKey) === "true";
}
export function clampSidebarWidth(width) {
    return Math.max(layoutDefaults.minSidebarWidth, Math.min(layoutDefaults.maxSidebarWidth, width));
}
export function persistSidebarWidth(width) {
    localStorage.setItem(sidebarWidthStorageKey, String(width));
}
export function persistSidebarCollapsed(collapsed) {
    localStorage.setItem(sidebarCollapsedStorageKey, collapsed ? "true" : "false");
}
export function persistTheme(theme) {
    localStorage.setItem(themeStorageKey, theme);
}
export function setCurrentDoc(state, path) {
    state.currentDoc = path;
}
export function setSearchQuery(state, query) {
    state.search.query = query;
}
export function setTextSearchState(state, nextSearch) {
    state.textSearch = nextSearch;
}
export function setTreeFilter(state, filter) {
    state.tree.filter = filter;
}
export function setTreeActivePath(state, activePath) {
    state.tree.activePath = activePath;
}
export function setTreeExpandedPaths(state, expandedPaths) {
    state.tree.expandedPaths = expandedPaths;
}
export function setOptionsMenuOpen(state, open) {
    state.optionsMenu.open = open;
}
export function setTheme(state, theme) {
    state.theme = theme;
}
export function setDocumentState(state, nextDocument) {
    state.document = nextDocument;
}
export function setViewerHtml(state, html) {
    state.viewer.html = html;
}
