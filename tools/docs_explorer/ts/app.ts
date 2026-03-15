import { marked } from "https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js";
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

import {
  initializeAppShell,
  syncHighlightTheme,
} from "./shell/app_shell.js";
import { getAppShell } from "./shell/shell_dom.js";
import { loadProjectConfig } from "./config.js";
import { createDocController } from "./docs/doc_controller.js";
import {
  installSidebarControls,
  syncResponsiveSidebarState,
} from "./layout.js";
import { configureMarked } from "./docs/markdown.js";
import { initMermaidForTheme } from "./docs/mermaid.js";
import { createAppState } from "./state.js";
import { installThemeControls } from "./theme/theme_controls.js";

export async function startApp(): Promise<void> {
  const hljs = window.hljs;
  const { project, docs } = await loadProjectConfig();
  const state = createAppState();
  const shell = getAppShell();

  await initializeAppShell({ shell, project, state });
  configureMarked(marked);
  initMermaidForTheme(mermaid, shell.rootEl, state.theme);

  const docController = createDocController({
    state,
    shell,
    appIconPath: project.icon,
    repoBasePath: project.repoBasePath,
    repoAbsolutePath: project.repoAbsolutePath,
    docs,
    defaultDocPath: project.defaultDoc,
    treeEl: shell.treeEl,
    viewerEl: shell.viewerEl,
    searchEl: shell.searchEl,
    marked,
    mermaid,
    hljs,
    rootEl: shell.rootEl,
  });

  docController.install();
  window.addEventListener("resize", () =>
    syncResponsiveSidebarState(shell.appEl, state),
  );
  installThemeControls({
    state,
    shell,
    docController,
    hljs,
    onThemeApplied: () => syncHighlightTheme(shell, state.theme),
  });
  installSidebarControls({
    appEl: shell.appEl,
    state,
    sidebarToggleEl: shell.sidebarToggleEl,
    sidebarResizerEl: shell.sidebarResizerEl,
  });

  docController.renderTree();
  await docController.renderCurrentDoc();
}
