/**
 * @typedef {{
 *   accent?: string,
 *   accentSoft?: string,
 *   accentStrong?: string,
 *   activeLink?: string,
 *   panel?: string,
 *   panel2?: string,
 *   panel3?: string,
 *   bg?: string,
 *   bg2?: string,
 * }} ProjectPalette
 */

/**
 * @typedef {{
 *   dark?: ProjectPalette,
 *   light?: ProjectPalette,
 * }} ProjectThemeConfig
 */

/**
 * @typedef {{
 *   title: string,
 *   icon: string,
 *   defaultDoc: string,
 *   docRoots: string[],
 *   includeExtensions: string[],
 *   theme?: ProjectThemeConfig,
 * }} ProjectConfig
 */

/**
 * @typedef {{
 *   currentDoc: string | null,
 *   theme: "dark" | "light",
 *   document: {
 *     title: string,
 *     subtitle: string,
 *     rawLink: string,
 *     status: "idle" | "loading" | "ready" | "error",
 *   },
 *   viewer: {
 *     html: string,
 *   },
 *   search: {
 *     query: string,
 *   },
 *   tree: {
 *     filter: string,
 *     activePath: string | null,
 *   },
 *   sidebar: {
 *     width: number,
 *     collapsed: boolean,
 *   },
 *   optionsMenu: {
 *     open: boolean,
 *   },
 * }} AppState
 */

/**
 * @typedef {{
 *   rootEl: HTMLElement,
 *   appEl: HTMLElement,
 *   treeEl: HTMLElement,
 *   viewerEl: HTMLElement,
 *   titleEl: HTMLElement,
 *   subtitleEl: HTMLElement,
 *   rawLinkEl: HTMLAnchorElement,
 *   searchEl: HTMLInputElement,
 *   optionsToggleEl: HTMLButtonElement,
 *   optionsMenuEl: HTMLElement,
 *   themeRowEl: HTMLElement,
 *   themeToggleEl: HTMLButtonElement,
 *   sidebarToggleEl: HTMLButtonElement,
 *   sidebarResizerEl: HTMLElement,
 *   appTitleEl: HTMLElement,
 *   brandMarkEl: HTMLImageElement,
 *   faviconEl: HTMLLinkElement,
 * }} AppShell
 */

export {};
