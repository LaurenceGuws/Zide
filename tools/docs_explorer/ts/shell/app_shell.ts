import { applySidebarWidth, syncResponsiveSidebarState } from "../layout.js";
import { injectShellIcons } from "./shell_icons.js";
import { applyProjectTheme } from "../theme/project_theme.js";
import { syncThemeVariables, updateThemeToggle } from "../theme/theme.js";
import type { AppShell, AppState, ProjectConfig } from "../shared/types.js";

export async function initializeAppShell(args: {
  shell: AppShell;
  project: ProjectConfig;
  state: AppState;
}): Promise<void> {
  const { shell, project, state } = args;
  document.title = project.title;
  shell.faviconEl.href = project.icon;
  shell.sourceLinkEl.href = project.repoUrl ?? "#";
  await injectShellIcons({
    sourceLinkIconEl: shell.sourceLinkIconEl,
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

export function syncHighlightTheme(
  shell: AppShell,
  theme: AppState["theme"],
): void {
  const isDark = theme === "dark";
  shell.highlightDarkThemeEl.disabled = !isDark;
  shell.highlightLightThemeEl.disabled = isDark;
}
