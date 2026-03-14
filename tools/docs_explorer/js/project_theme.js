const themeVarMap = {
  bg: "--bg",
  bg2: "--bg-2",
  panel: "--panel",
  panel2: "--panel-2",
  panel3: "--panel-3",
  accent: "--accent",
  accentSoft: "--accent-soft",
  accentStrong: "--accent-strong",
  activeLink: "--active-link",
};

/**
 * @param {HTMLElement} rootEl
 * @param {import("./types.js").ProjectConfig} project
 */
export function applyProjectTheme(rootEl, project) {
  const theme = project.theme || {};
  applyThemeOverrides(rootEl, theme.dark, "dark");
  applyThemeOverrides(rootEl, theme.light, "light");
}

/**
 * @param {HTMLElement} rootEl
 * @param {import("./types.js").ProjectPalette | undefined} themeValues
 * @param {"dark" | "light"} themeName
 */
function applyThemeOverrides(rootEl, themeValues, themeName) {
  if (!themeValues) return;
  for (const [key, cssVar] of Object.entries(themeVarMap)) {
    if (!(key in themeValues)) continue;
    rootEl.style.setProperty(scopedThemeVar(cssVar, themeName), themeValues[key]);
  }
}

/** @param {string} cssVar
 *  @param {"dark" | "light"} themeName
 */
function scopedThemeVar(cssVar, themeName) {
  return `${cssVar}-${themeName}`;
}
