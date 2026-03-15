import { applySidebarWidth, syncResponsiveSidebarState } from "./layout.js";
import { applyProjectTheme } from "./project_theme.js";
import { syncThemeVariables, updateThemeToggle } from "./theme.js";
export function getAppShell() {
    return {
        rootEl: document.documentElement,
        appEl: requiredElement(".app"),
        treeEl: requiredElement("#tree"),
        viewerEl: requiredElement("#viewer"),
        titleEl: requiredElement("#doc-title"),
        subtitleEl: requiredElement("#doc-subtitle"),
        rawLinkEl: requiredElement("#raw-link"),
        searchEl: requiredElement("#search"),
        optionsToggleEl: requiredElement("#options-toggle"),
        optionsMenuEl: requiredElement("#options-menu"),
        optionsInfoEl: requiredElement("#options-info"),
        themeRowEl: requiredElement("#theme-row"),
        themeToggleEl: requiredElement("#theme-toggle"),
        sidebarToggleEl: requiredElement("#sidebar-toggle"),
        sidebarResizerEl: requiredElement("#sidebar-resizer"),
        appTitleEl: requiredElement("#app-title"),
        brandMarkEl: requiredElement("#brand-mark"),
        faviconEl: requiredElement("#favicon"),
        highlightDarkThemeEl: requiredElement("#hljs-dark-theme"),
        highlightLightThemeEl: requiredElement("#hljs-light-theme"),
    };
}
export function initializeAppShell(args) {
    const { shell, project, state } = args;
    document.title = project.title;
    applyBrandWordmark(shell, project);
    shell.brandMarkEl.src = project.icon;
    shell.brandMarkEl.alt = "Z";
    shell.faviconEl.href = project.icon;
    applyProjectTheme(shell.rootEl, project);
    shell.rootEl.dataset.theme = state.theme;
    syncThemeVariables(shell.rootEl, state.theme);
    syncHighlightTheme(shell, state.theme);
    applySidebarWidth(shell.appEl, state, state.sidebar.width);
    syncResponsiveSidebarState(shell.appEl, state);
    updateThemeToggle(shell.themeToggleEl, state.theme);
}
export function syncHighlightTheme(shell, theme) {
    const isDark = theme === "dark";
    shell.highlightDarkThemeEl.disabled = !isDark;
    shell.highlightLightThemeEl.disabled = isDark;
}
function applyBrandWordmark(shell, project) {
    const title = project.title;
    if (!title.startsWith("Z")) {
        shell.appTitleEl.textContent = title;
        return;
    }
    shell.appTitleEl.textContent = title.slice(1);
}
function requiredElement(selector) {
    const el = document.querySelector(selector);
    if (!el) {
        throw new Error(`Missing required element: ${selector}`);
    }
    return el;
}
