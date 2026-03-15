import { marked } from "https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js";
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

import { bootstrapAppRuntime } from "./app_bootstrap.js";
import { loadProjectConfig } from "./config.js";
import {
  installSidebarControls,
  syncResponsiveSidebarState,
} from "./layout.js";
import { installDocSearch } from "./search/doc_search.js";
import { syncHighlightTheme } from "./shell/app_shell.js";
import { installThemeControls } from "./theme/theme_controls.js";

export async function startApp(): Promise<void> {
  const hljs = window.hljs;
  const { project, docs } = await loadProjectConfig();
  const { state, shell, docController } = await bootstrapAppRuntime({
    project,
    docs,
    marked,
    mermaid,
    hljs,
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
  installDocSearch({
    state,
    shell,
    docs,
    enabled: project.runtimeMode === "local-dev",
  });

  docController.renderTree();
  await docController.renderCurrentDoc();
}
