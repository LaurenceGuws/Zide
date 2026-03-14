import { marked } from "https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js";
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";

import { getAppShell, initializeAppShell } from "./app_shell.js";
import { loadProjectConfig } from "./config.js";
import { createDocController } from "./doc_controller.js";
import { installSidebarControls, syncResponsiveSidebarState } from "./layout.js";
import { configureMarked } from "./markdown.js";
import { initMermaidForTheme } from "./mermaid.js";
import { installOptionsMenu } from "./options_menu.js";
import { createAppState, persistTheme, setTheme } from "./state.js";
import { applyTheme } from "./theme.js";

export async function startApp(): Promise<void> {
  const { project, docs } = await loadProjectConfig();
  const state = createAppState();
  const shell = getAppShell();

  initializeAppShell({ shell, project, state });
  configureMarked(marked);
  initMermaidForTheme(mermaid, shell.rootEl, state.theme);

  const docController = createDocController({
    state,
    shell,
    repoBasePath: project.repoBasePath,
    docs,
    defaultDocPath: project.defaultDoc,
    treeEl: shell.treeEl,
    viewerEl: shell.viewerEl,
    searchEl: shell.searchEl,
    marked,
    mermaid,
    rootEl: shell.rootEl,
  });

  docController.install();
  window.addEventListener("resize", () => syncResponsiveSidebarState(shell.appEl, state));
  installOptionsMenu({
    state,
    optionsToggleEl: shell.optionsToggleEl,
    optionsMenuEl: shell.optionsMenuEl,
    onThemeToggle(registerClose: () => void) {
      const handleThemeToggle = async (): Promise<void> => {
        const nextTheme = state.theme === "dark" ? "light" : "dark";
        registerClose();
        setTheme(state, nextTheme);
        await applyTheme(
          shell.rootEl,
          shell.themeToggleEl,
          state.theme,
          persistTheme,
          () => docController.rerenderDiagramsForTheme(),
        );
      };

      shell.themeToggleEl.addEventListener("click", async (event: MouseEvent) => {
        event.stopPropagation();
        await handleThemeToggle();
      });
      shell.themeRowEl.addEventListener("click", async () => {
        await handleThemeToggle();
      });
    },
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
