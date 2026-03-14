import { applySidebarWidth, syncResponsiveSidebarState } from "./layout.js";
import { applyProjectTheme } from "./project_theme.js";
import { syncThemeVariables, updateThemeToggle } from "./theme.js";

/** @returns {import("./types.js").AppShell} */
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
    themeRowEl: requiredElement("#theme-row"),
    themeToggleEl: requiredElement("#theme-toggle"),
    sidebarToggleEl: requiredElement("#sidebar-toggle"),
    sidebarResizerEl: requiredElement("#sidebar-resizer"),
    appTitleEl: requiredElement("#app-title"),
    brandMarkEl: requiredElement("#brand-mark"),
    faviconEl: requiredElement("#favicon"),
  };
}

/**
 * @param {{
 *   shell: import("./types.js").AppShell,
 *   project: import("./types.js").ProjectConfig,
 *   state: import("./types.js").AppState,
 * }} args
 */
export function initializeAppShell({ shell, project, state }) {
  document.title = project.title;
  shell.appTitleEl.textContent = project.title;
  shell.brandMarkEl.src = project.icon;
  shell.brandMarkEl.alt = `${project.title} logo`;
  shell.faviconEl.href = project.icon;

  applyProjectTheme(shell.rootEl, project);
  shell.rootEl.dataset.theme = state.theme;
  syncThemeVariables(shell.rootEl, state.theme);
  applySidebarWidth(shell.appEl, state, state.sidebar.width);
  syncResponsiveSidebarState(shell.appEl, state);
  updateThemeToggle(shell.themeToggleEl, state.theme);
}

/** @param {string} selector */
function requiredElement(selector) {
  const el = document.querySelector(selector);
  if (!el) {
    throw new Error(`Missing required element: ${selector}`);
  }
  return el;
}
