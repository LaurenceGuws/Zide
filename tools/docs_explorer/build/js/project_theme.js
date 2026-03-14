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
export function applyProjectTheme(rootEl, project) {
    const theme = project.theme || {};
    applyThemeOverrides(rootEl, theme.dark, "dark");
    applyThemeOverrides(rootEl, theme.light, "light");
}
function applyThemeOverrides(rootEl, themeValues, themeName) {
    if (!themeValues)
        return;
    for (const [key, cssVar] of Object.entries(themeVarMap)) {
        const value = themeValues[key];
        if (value === undefined)
            continue;
        rootEl.style.setProperty(scopedThemeVar(cssVar, themeName), value);
    }
}
function scopedThemeVar(cssVar, themeName) {
    return `${cssVar}-${themeName}`;
}
