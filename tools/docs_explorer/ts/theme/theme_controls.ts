import { renderHighlightedCode } from "../docs/highlight.js";
import { installOptionsMenu } from "../options_menu.js";
import { persistTheme, setTheme } from "../state.js";
import type {
  AppShell,
  AppState,
  DocController,
  ThemeName,
} from "../shared/types.js";
import type { HighlightJsApi } from "../shared/vendor_types.js";
import { applyTheme } from "./theme.js";

export function installThemeControls(args: {
  state: AppState;
  shell: AppShell;
  docController: DocController;
  hljs?: HighlightJsApi;
  onThemeApplied?: () => void;
}): void {
  const { state, shell, docController, hljs, onThemeApplied } = args;

  installOptionsMenu({
    state,
    optionsToggleEl: shell.optionsToggleEl,
    optionsMenuEl: shell.optionsMenuEl,
    onThemeToggle(registerClose: () => void) {
      const handleThemeToggle = async (): Promise<void> => {
        const nextTheme: ThemeName = state.theme === "dark" ? "light" : "dark";
        registerClose();
        setTheme(state, nextTheme);
        await applyTheme(
          shell.rootEl,
          shell.themeToggleEl,
          state.theme,
          persistTheme,
          () => docController.rerenderDiagramsForTheme(),
        );
        onThemeApplied?.();
        renderHighlightedCode(hljs, shell.viewerEl);
      };

      shell.themeToggleEl.addEventListener(
        "click",
        async (event: MouseEvent) => {
          event.stopPropagation();
          await handleThemeToggle();
        },
      );
      shell.themeRowEl.addEventListener("click", async () => {
        await handleThemeToggle();
      });
    },
  });
}
