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
        sourceLinkEl: requiredElement("#source-link"),
        sourceLinkIconEl: requiredElement("#source-link-icon"),
        searchEl: requiredElement("#search"),
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
export async function initializeAppShell(args) {
    const { shell, project, state } = args;
    document.title = project.title;
    shell.faviconEl.href = project.icon;
    await Promise.all([
        injectSvg(shell.sourceLinkIconEl, "./assets/icons/github.svg"),
        injectSvg(shell.optionsToggleIconEl, "./assets/icons/ellipsis.svg"),
        injectSvg(shell.sidebarToggleIconEl, "./assets/icons/sidebar.svg"),
    ]);
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
async function injectSvg(target, path) {
    const response = await fetch(path);
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} for ${path}`);
    }
    const svg = await response.text();
    target.innerHTML = svg;
    const svgEl = target.querySelector("svg");
    if (svgEl) {
        svgEl.setAttribute("width", "16");
        svgEl.setAttribute("height", "16");
        svgEl.setAttribute("preserveAspectRatio", "xMidYMid meet");
        svgEl.setAttribute("focusable", "false");
    }
}
function requiredElement(selector) {
    const el = document.querySelector(selector);
    if (!el) {
        throw new Error(`Missing required element: ${selector}`);
    }
    return el;
}
