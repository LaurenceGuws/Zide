export type ThemeName = "dark" | "light";
export type DocumentStatus = "idle" | "loading" | "ready" | "error";

export type ProjectPalette = {
  accent?: string;
  accentSoft?: string;
  accentStrong?: string;
  activeLink?: string;
  panel?: string;
  panel2?: string;
  panel3?: string;
  bg?: string;
  bg2?: string;
};

export type ProjectThemeConfig = {
  dark?: ProjectPalette;
  light?: ProjectPalette;
};

export type ProjectConfig = {
  title: string;
  icon: string;
  repoBasePath: string;
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
  searchEl: HTMLInputElement;
  optionsToggleEl: HTMLButtonElement;
  optionsMenuEl: HTMLElement;
  optionsInfoEl: HTMLElement;
  themeRowEl: HTMLElement;
  themeToggleEl: HTMLButtonElement;
  sidebarToggleEl: HTMLButtonElement;
  sidebarResizerEl: HTMLElement;
  appTitleEl: HTMLElement;
  brandMarkEl: HTMLImageElement;
  faviconEl: HTMLLinkElement;
};
