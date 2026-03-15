export type ThemeName = "dark" | "light";
export type DocumentStatus = "idle" | "loading" | "ready" | "error";

// Only base palette tokens belong in project config. Derived shell/control/viewer
// materials remain CSS-owned so the tool keeps one design system instead of a
// per-project styling DSL.
export type ProjectPalette = {
  accent?: string;
  accentSoft?: string;
  accentStrong?: string;
  activeLink?: string;
  code?: string;
  ink?: string;
  line?: string;
  lineSoft?: string;
  muted?: string;
  panel?: string;
  panel2?: string;
  panel3?: string;
  bg?: string;
  bg2?: string;
  treeActive?: string;
};

export type ProjectThemeConfig = {
  dark?: ProjectPalette;
  light?: ProjectPalette;
};

export type ProjectConfig = {
  title: string;
  icon: string;
  repoAbsolutePath?: string;
  repoBasePath: string;
  repoUrl?: string;
  runtimeMode?: string;
  defaultDoc: string;
  docRoots: string[];
  includeExtensions: string[];
  theme?: ProjectThemeConfig;
};

export type AppState = {
  currentDoc: string | null;
  theme: ThemeName;
  document: {
    title: string;
    subtitle: string;
    rawLink: string;
    status: DocumentStatus;
  };
  viewer: {
    html: string;
  };
  search: {
    query: string;
  };
  tree: {
    filter: string;
    activePath: string | null;
    expandedPaths: string[];
  };
  sidebar: {
    width: number;
    collapsed: boolean;
  };
  optionsMenu: {
    open: boolean;
  };
};

export type AppShell = {
  rootEl: HTMLElement;
  appEl: HTMLElement;
  treeEl: HTMLElement;
  viewerEl: HTMLElement;
  titleEl: HTMLElement;
  subtitleEl: HTMLElement;
  rawLinkEl: HTMLAnchorElement;
  sourceLinkEl: HTMLAnchorElement;
  sourceLinkIconEl: HTMLElement;
  searchEl: HTMLInputElement;
  optionsToggleEl: HTMLButtonElement;
  optionsToggleIconEl: HTMLElement;
  optionsMenuEl: HTMLElement;
  themeRowEl: HTMLElement;
  themeToggleEl: HTMLButtonElement;
  sidebarToggleEl: HTMLButtonElement;
  sidebarToggleIconEl: HTMLElement;
  sidebarResizerEl: HTMLElement;
  faviconEl: HTMLLinkElement;
  highlightDarkThemeEl: HTMLLinkElement;
  highlightLightThemeEl: HTMLLinkElement;
};

export type DocController = {
  install: () => void;
  renderTree: () => void;
  renderCurrentDoc: () => Promise<void>;
  rerenderDiagramsForTheme: () => Promise<void>;
};
