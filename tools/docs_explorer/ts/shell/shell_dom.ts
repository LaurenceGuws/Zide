import type { AppShell } from "../shared/types.js";

export function getAppShell(): AppShell {
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

function requiredElement<T extends Element>(selector: string): T {
  const el = document.querySelector<T>(selector);
  if (!el) {
    throw new Error(`Missing required element: ${selector}`);
  }
  return el;
}
