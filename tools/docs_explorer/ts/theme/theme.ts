import type { ThemeName } from "../shared/types.js";

export function currentTheme(rootEl: HTMLElement): ThemeName {
  return rootEl.dataset.theme === "light" ? "light" : "dark";
}

export function themeVariables(
  rootEl: HTMLElement,
  theme: ThemeName,
): Record<string, string | boolean> {
  const css = getComputedStyle(rootEl);
  return {
    primaryColor: css.getPropertyValue("--mermaid-primary").trim(),
    primaryTextColor: css.getPropertyValue("--mermaid-primary-text").trim(),
    primaryBorderColor: css.getPropertyValue("--mermaid-primary-border").trim(),
    lineColor: css.getPropertyValue("--mermaid-line").trim(),
    secondaryColor: css.getPropertyValue("--mermaid-secondary").trim(),
    tertiaryColor: css.getPropertyValue("--mermaid-tertiary").trim(),
    clusterBkg: css.getPropertyValue("--mermaid-cluster").trim(),
    clusterBorder: css.getPropertyValue("--mermaid-cluster-border").trim(),
    labelBackground: css.getPropertyValue("--mermaid-label-bg").trim(),
    fontFamily: css.getPropertyValue("--font-diagram").trim(),
    darkMode: theme === "dark",
  };
}

export function syncThemeVariables(
  rootEl: HTMLElement,
  theme: ThemeName,
): void {
  const varNames = [
    "--bg",
    "--bg-2",
    "--panel",
    "--panel-2",
    "--panel-3",
    "--ink",
    "--muted",
    "--line",
    "--line-soft",
    "--accent",
    "--accent-soft",
    "--accent-strong",
    "--active-link",
    "--code",
    "--tree-active",
  ];

  for (const varName of varNames) {
    const scoped = `${varName}-${theme}`;
    const value = getComputedStyle(rootEl).getPropertyValue(scoped).trim();
    if (value) {
      rootEl.style.setProperty(varName, value);
    }
  }
}

export function updateThemeToggle(
  toggleEl: HTMLButtonElement,
  theme: ThemeName,
): void {
  toggleEl.setAttribute(
    "aria-label",
    theme === "dark" ? "Switch to light theme" : "Switch to dark theme",
  );
  toggleEl.title =
    theme === "dark" ? "Switch to light theme" : "Switch to dark theme";
  toggleEl.setAttribute("aria-pressed", theme === "light" ? "true" : "false");
}

export async function applyTheme(
  rootEl: HTMLElement,
  toggleEl: HTMLButtonElement,
  theme: ThemeName,
  persistTheme: (theme: ThemeName) => void,
  rerenderVisibleMermaid: () => Promise<void>,
): Promise<void> {
  rootEl.dataset.theme = theme;
  persistTheme(theme);
  syncThemeVariables(rootEl, theme);
  updateThemeToggle(toggleEl, theme);
  await rerenderVisibleMermaid();
}
