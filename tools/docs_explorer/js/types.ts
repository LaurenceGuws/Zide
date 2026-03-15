export type ThemeName = "dark" | "light";
export type DocumentStatus = "idle" | "loading" | "ready" | "error";
export type SearchStatus =
  | "idle"
  | "loading"
  | "ready"
  | "error"
  | "unavailable";

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
  textSearch: {
    query: string;
    open: boolean;
    status: SearchStatus;
    selectedIndex: number;
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
  globalSearchEl: HTMLInputElement;
  globalSearchModalEl: HTMLElement;
  globalSearchResultsEl: HTMLElement;
  globalSearchStatusEl: HTMLElement;
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
<<<<<<< HEAD:tools/docs_explorer/js/types.ts
=======

export type DocController = {
  install: () => void;
  renderTree: () => void;
  renderCurrentDoc: () => Promise<void>;
  rerenderDiagramsForTheme: () => Promise<void>;
};

export type SearchHit = {
  path: string;
  line: number;
  column: number;
  preview: string;
  matchText: string;
  start: number;
  end: number;
};
>>>>>>> cba2f82 (Add docs explorer ripgrep search):tools/docs_explorer/ts/shared/types.ts
