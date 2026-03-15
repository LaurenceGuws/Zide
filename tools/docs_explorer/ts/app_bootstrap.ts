import type { DocController, ProjectConfig } from "./shared/types.js";
import type {
  HighlightJsApi,
  MarkedApi,
  MermaidApi,
} from "./shared/vendor_types.js";
import { createDocController } from "./docs/doc_controller.js";
import { configureMarked } from "./docs/markdown.js";
import { initMermaidForTheme } from "./docs/mermaid.js";
import { initializeAppShell, syncHighlightTheme } from "./shell/app_shell.js";
import { getAppShell } from "./shell/shell_dom.js";
import { createAppState } from "./state.js";

export async function bootstrapAppRuntime(args: {
  project: ProjectConfig;
  docs: string[];
  marked: MarkedApi;
  mermaid: MermaidApi;
  hljs?: HighlightJsApi;
}): Promise<{
  state: ReturnType<typeof createAppState>;
  shell: ReturnType<typeof getAppShell>;
  docController: DocController;
}> {
  const { project, docs, marked, mermaid, hljs } = args;
  const state = createAppState();
  const shell = getAppShell();

  await initializeAppShell({ shell, project, state });
  configureMarked(marked);
  initMermaidForTheme(mermaid, shell.rootEl, state.theme);
  syncHighlightTheme(shell, state.theme);

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

  return { state, shell, docController };
}
