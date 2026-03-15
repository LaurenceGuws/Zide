import { renderHighlightedCode } from "../docs/highlight.js";
import { installOptionsMenu } from "../options_menu.js";
import { persistTheme, setTheme } from "../state.js";
import { applyTheme } from "./theme.js";
export function installThemeControls(args) {
    const { state, shell, docController, hljs, onThemeApplied } = args;
    installOptionsMenu({
        state,
        optionsToggleEl: shell.optionsToggleEl,
        optionsMenuEl: shell.optionsMenuEl,
        onThemeToggle(registerClose) {
            const handleThemeToggle = async () => {
                const nextTheme = state.theme === "dark" ? "light" : "dark";
                registerClose();
                setTheme(state, nextTheme);
                await applyTheme(shell.rootEl, shell.themeToggleEl, state.theme, persistTheme, () => docController.rerenderDiagramsForTheme());
                onThemeApplied?.();
                renderHighlightedCode(hljs, shell.viewerEl);
            };
            shell.themeToggleEl.addEventListener("click", async (event) => {
                event.stopPropagation();
                await handleThemeToggle();
            });
            shell.themeRowEl.addEventListener("click", async () => {
                await handleThemeToggle();
            });
        },
    });
}
