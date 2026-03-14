export const themeStorageKey = "zide_docs_explorer.theme";

export function currentTheme(rootEl) {
  return rootEl.dataset.theme === "light" ? "light" : "dark";
}

export function preferredTheme() {
  const stored = localStorage.getItem(themeStorageKey);
  if (stored === "light" || stored === "dark") return stored;
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

export function themeVariables(rootEl, theme) {
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

export function updateThemeToggle(toggleEl, theme) {
  toggleEl.textContent = theme === "dark" ? "◐" : "◑";
  toggleEl.setAttribute("aria-label", theme === "dark" ? "Switch to light theme" : "Switch to dark theme");
  toggleEl.title = theme === "dark" ? "Switch to light theme" : "Switch to dark theme";
}

export async function applyTheme(rootEl, toggleEl, theme, rerenderVisibleMermaid) {
  rootEl.dataset.theme = theme;
  localStorage.setItem(themeStorageKey, theme);
  updateThemeToggle(toggleEl, theme);
  await rerenderVisibleMermaid();
}
