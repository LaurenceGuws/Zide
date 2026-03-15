export function getAppShell() {
    return {
        rootEl: document.documentElement,
        appEl: requiredElement(".app"),
        treeEl: requiredElement("#tree"),
        viewerEl: requiredElement("#viewer"),
        titleEl: requiredElement("#doc-title"),
        subtitleEl: requiredElement("#doc-subtitle"),
        rawLinkEl: requiredElement("#raw-link"),
        sourceLinkEl: requiredElement("#source-link"),
        sourceLinkIconEl: requiredElement("#source-link-icon"),
        supportLinkEl: requiredElement("#support-link"),
        supportLinkIconEl: requiredElement("#support-link-icon"),
        supportLinkLabelEl: requiredElement("#support-link-label"),
        searchEl: requiredElement("#search"),
        globalSearchEl: requiredElement("#global-search"),
        globalSearchModalEl: requiredElement("#global-search-modal"),
        globalSearchResultsEl: requiredElement("#global-search-results"),
        globalSearchStatusEl: requiredElement("#global-search-status"),
        optionsToggleEl: requiredElement("#options-toggle"),
        optionsToggleIconEl: requiredElement("#options-toggle-icon"),
        optionsMenuEl: requiredElement("#options-menu"),
        themeRowEl: requiredElement("#theme-row"),
        themeToggleEl: requiredElement("#theme-toggle"),
        sidebarToggleEl: requiredElement("#sidebar-toggle"),
        sidebarToggleIconEl: requiredElement("#sidebar-toggle-icon"),
        sidebarResizerEl: requiredElement("#sidebar-resizer"),
        faviconEl: requiredElement("#favicon"),
        highlightDarkThemeEl: requiredElement("#hljs-dark-theme"),
        highlightLightThemeEl: requiredElement("#hljs-light-theme"),
    };
}
function requiredElement(selector) {
    const el = document.querySelector(selector);
    if (!el) {
        throw new Error(`Missing required element: ${selector}`);
    }
    return el;
}
