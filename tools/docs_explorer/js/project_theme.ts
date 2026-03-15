import type { ProjectConfig, ProjectPalette, ThemeName } from "./types.js";

const themeVarMap: Record<keyof ProjectPalette, string> = {
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

export function applyProjectTheme(
  rootEl: HTMLElement,
  project: ProjectConfig,
): void {
  const theme = project.theme || {};
  applyThemeOverrides(rootEl, theme.dark, "dark");
  applyThemeOverrides(rootEl, theme.light, "light");
}

function applyThemeOverrides(
  rootEl: HTMLElement,
  themeValues: ProjectPalette | undefined,
  themeName: ThemeName,
): void {
  if (!themeValues) return;
  for (const [key, cssVar] of Object.entries(themeVarMap) as Array<
    [keyof ProjectPalette, string]
  >) {
    const value = themeValues[key];
    if (value === undefined) continue;
    rootEl.style.setProperty(scopedThemeVar(cssVar, themeName), value);
  }
}

function scopedThemeVar(cssVar: string, themeName: ThemeName): string {
  return `${cssVar}-${themeName}`;
}
