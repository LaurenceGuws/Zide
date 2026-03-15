import { applySidebarWidth, syncResponsiveSidebarState } from "../layout.js";
import { injectShellIcons } from "./shell_icons.js";
import { applyProjectTheme } from "../theme/project_theme.js";
import { syncThemeVariables, updateThemeToggle } from "../theme/theme.js";
export async function initializeAppShell(args) {
    const { shell, project, state } = args;
    document.title = project.title;
    shell.faviconEl.href = project.icon;
    shell.sourceLinkEl.href = project.repoUrl ?? "#";
    if (project.supportUrl) {
        shell.supportLinkEl.href = project.supportUrl;
        shell.supportLinkLabelEl.textContent = project.supportLabel ?? "Support";
        shell.supportLinkEl.hidden = false;
    }
    else {
        shell.supportLinkEl.hidden = true;
    }
    await injectShellIcons({
        sourceLinkIconEl: shell.sourceLinkIconEl,
        supportLinkIconEl: shell.supportLinkIconEl,
        optionsToggleIconEl: shell.optionsToggleIconEl,
        sidebarToggleIconEl: shell.sidebarToggleIconEl,
    });
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
